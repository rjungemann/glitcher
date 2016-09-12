require 'chunky_png'
require 'glitcher/version'
require 'glitcher/patches'

module Glitcher
  class JPEG
    # Only modify data delineated by the symbol indicating a new "huffman table"
    # is being defined (http://en.wikipedia.org/wiki/JPEG).
    DELINEATOR = 'ffc4'

    def initialize(infile)
      @infile = infile
      @input ||= File.read(@infile).unpack("H*").first

      indices = []
      while(indices.size < 1 || indices.last != nil)
        first = @input.index(DELINEATOR, indices.size < 1 ? 0 : indices.last.max)
        range = first ? (first..(first + DELINEATOR.size)) : nil
        indices << range
      end
      indices.pop if indices.last.nil?

      @indices = []
      indices.each_with_index do |index, i|
        next if i < 1
        @indices << ((indices[(i - 1)].max + 1)..(indices[i].min) - 1)
      end
    end

    def munge_basic
      @input[rand(@input.size)] = rand(16).to_s(16)
      self
    end

    def munge_swap_adjacent
      i = @indices.pick.pick
      @input.swap(i, i + 1)
      self
    end

    def munge_swap
      first = @indices.pick.pick
      second = first
      second = @indices.pick.pick while first == second
      @input.swap(first, second)
      self
    end

    def munge
      mthd = Glitcher::JPEG
        .instance_methods
        .select { |m| m.to_s.match(/^munge_/) }
        .pick
      send(mthd, n)
    end

    def save!(path)
      extname = File.extname(path)
      rest = path[0...-File.extname(path).length]
      raise 'Must have a .jpg extension.' unless extname == '.jpg'
      File.open(path, 'w') do |f|
        f.puts([@input].pack('H*'))
      end
      `convert #{rest}.jpg #{rest}.2.jpg >/dev/null 2>&1`
      `rm #{rest}.jpg`
      `mv #{rest}.2.jpg #{rest}.jpg >/dev/null 2>&1`
    end
  end

  class ImageMunger
    def initialize
    end

    def save!
      `mkdir -p source`
      image = 'source.jpg'
      flipped_image = 'source.flipped.jpg'
      `convert -flop #{image} #{flipped_image}`
      100.times do |i|
        puts "Generating frame #{i + 1}..."
        loop do
          is_flipped = (rand(2) == 1)
          path = is_flipped ? flipped_image : image
          jpeg = Glitcher::JPEG.new(path)
          n = rand(20) + 1
          n.times do
            jpeg.munge
          end
          jpeg.save!("source/#{i}.jpg")
          if File.exists?("source/#{i}.jpg")
            if is_flipped
              `convert -flop "source/#{i}.jpg" "source/#{i}.flipped.jpg"`
              `rm "source/#{i}.jpg"`
              `mv "source/#{i}.flipped.jpg" "source/#{i}.jpg"`
            end
            break
          end
        end
      end
      `rm "#{flipped_image}"`
      `rm source/video.mp4 >/dev/null 2>&1`
      `ffmpeg -i source/%d.jpg source/video.mp4`
    end
  end

  class VideoMunger
    def initialize
    end

    def save!
      `rm -rf input`
      `rm -rf source`
      `mkdir -p input`
      `mkdir -p source`
      fps = `ffmpeg -i source.mov 2>&1`.match(/([\d\.]+) fps/)[1]
      `ffmpeg -i source.mov -r #{fps}/1 input/%d.jpg`
      Dir.glob('input/*.jpg').each do |path|
        is_flipped = (rand(2) == 1)
        basename = File.basename(path)
        extname = File.extname(path)
        rest = path[0...-extname.length]
        raw_i = basename[0...-extname.length]
        puts "Generating frame #{raw_i.to_i + 1}..."
        i = raw_i.rjust(10, '0')
        actual_path = path
        if is_flipped
          flipped_path = "#{rest}.flipped.jpg"
          `convert -flop "#{path}" "#{flipped_path}"`
          actual_path = flipped_path
        end
        begin
          jpeg = Glitcher::JPEG.new(actual_path)
          n = rand(20) + 1
          n.times do
            jpeg.munge
          end
          jpeg.save!("source/#{i}.jpg")
        rescue StandardError => e
          # TODO: Figure out why this happens
          jpeg.save!("source/#{i}.jpg")
        end
        redo unless File.exists?("source/#{i}.jpg")
        if is_flipped
          `convert -flop "source/#{i}.jpg" "source/#{i}.flipped.jpg"`
          `rm "source/#{i}.jpg"`
          `mv "source/#{i}.flipped.jpg" "source/#{i}.jpg"`
        end
      end
      `rm source/video.mp4 >/dev/null 2>&1`
      `ffmpeg -i source/%10d.jpg source/video.mp4`
    end
  end

  class Sorter
    def initialize
    end

    def save!
      puts 'Loading mask...'
      mask = ChunkyPNG::Image.from_file('mask.png')

      puts 'Loading source...'
      source = ChunkyPNG::Image.from_file('source.png')

      puts 'Checking constraints...'
      width = mask.width
      height = mask.height
      raise 'Widths must match.' unless source.width == width
      raise 'Heights must match.' unless source.height == height

      puts 'Sorting pixels...'
      height.times do |j|
        start_i = nil
        end_i = nil
        width.times do |i|
          color = ChunkyPNG::Color.to_hsv(mask[i, j], include_alpha: true)
          # Find the first black pixel in a range.
          if start_i.nil? && color.third < 0.5
            start_i = i
          end
          # Find the last black pixel in a range.
          if start_i && color.third > 0.5
            end_i = i - 1
          end
          # If we hit end without finding non-black pixel, mark last as end.
          if end_i == nil && i == width - 1
            end_i = width - 1
          end

          # Once we find the start and end, sort pixels in range.
          if start_i && end_i
            pixels = (start_i..end_i)
              .map { |i|
                ChunkyPNG::Color.to_hsv(source[i, j])
              }
              .sort_by { |color|
                -color.third
              }
              .map { |color|
                hue = color.first
                hue += 360 if hue < 0
                ChunkyPNG::Color.from_hsv(hue, color.second, color.third)
              }

            (start_i..end_i).each.with_index do |i, pixels_i|
              source[i, j] = pixels[pixels_i]
            end

            # Reset start_i and end_i and start searching again.
            start_i = nil
            end_i = nil
          end
        end
      end

      puts 'Writing destination...'
      source.save('destination3.png')

      puts 'Done!'
    end
  end

  class Sorter2
    attr_accessor :source, :width, :height

    def initialize(path)
      @source = ChunkyPNG::Image.from_file(path)
      @width = @source.width
      @height = @source.height
    end

    def sort
      height.times do |j|
        start_i = nil
        end_i = nil
        width.times do |i|
          color = ChunkyPNG::Color.to_hsv(source[i, j], include_alpha: true)
          # Find the first non-black pixel in a range.
          if start_i.nil? && start_sort?(color, i, j)
            start_i = i
          end
          # Find the last black pixel in a range.
          if start_i && end_sort?(color, i, j)
            end_i = i - 1
          end
          # If we hit end without finding non-black pixel, mark last as end.
          if end_i == nil && i == width - 1
            end_i = width - 1
          end

          # Once we find the start and end, sort pixels in range.
          if start_i && end_i
            pixels = (start_i..end_i)
              .map { |i| ChunkyPNG::Color.to_hsv(source[i, j]) }
              .sort_by { |color| sort_by(color) }
              .map { |color|
                hue = color.first
                hue += 360 if hue < 0
                ChunkyPNG::Color.from_hsv(hue, color.second, color.third)
              }

            (start_i..end_i).each.with_index do |i, pixels_i|
              source[i, j] = pixels[pixels_i]
            end

            # Reset start_i and end_i and start searching again.
            start_i = nil
            end_i = nil
          end
        end
      end
    end

    def start_sort?(color, i, j)
      color.third > 0.3
    end

    def end_sort?(color, i, j)
      color.third <= 0.3
    end

    def sort_by(color)
      # -color.third
      color.third
    end

    def save!(path)
      source.save(path)
    end

    # puts 'Loading source...'
    # sorter = Sorter.new('source.png')
    # # sorter.source = sorter.source.rotate_right
    # puts 'Sorting pixels...'
    # sorter.sort
    # # sorter.source = sorter.source.rotate_left
    # puts 'Writing destination...'
    # sorter.save!('destination.png')
    # puts 'Done!'

    # `rm -rf input`
    # `rm -rf destination`
    # `mkdir -p input`
    # `mkdir -p destination`
    # fps = `ffmpeg -i source.mov 2>&1`.match(/([\d\.]+) fps/)[1]
    # `ffmpeg -i source.mov -r #{fps}/1 input/%10d.png`

    ###

    # Dir.glob('input/*.png').each do |path|
    #   puts path
    #   puts 'Loading source...'
    #   sorter = Sorter.new(path)
    #   puts 'Sorting pixels...'
    #   sorter.sort
    #   puts 'Writing destination...'

    #   basename = File.basename(path)
    #   sorter.save!("destination/#{basename}")
    # end
    # puts 'Exporting video...'
    # `rm video.mp4 >/dev/null 2>&1`
    # `ffmpeg -i destination/%10d.png video.mp4`
    # puts 'Done!'
  end

  # cp chairs.mp3 chairs.raw
  # sqrt=$(
  #   wc -c chairs.raw |
  #     awk '{print $1}' |
  #     ruby -e 'puts (gets.to_i ** 0.5).ceil'
  # )
  # dimensions=$(echo "$sqrt"x"$sqrt")
  # convert -size $dimensions -depth 8 gray:chairs.raw chairs.bmp
  # # Do stuff with it...
  # convert -size $dimensions -depth 8 chairs2.bmp gray:chairs2.raw
  # cp chairs2.raw chairs2.mp3
  # sox chairs2.mp3 chairs2.wav
  # 
  # wc -c chairs.raw | ruby -e 'puts (gets.chomp.split(/\s+/).first.to_i ** 0.5).ceil'
  # 
  # sox -V3 "Freeze 3-Audio-1.wav" output.wav silence 1 3.0 0.1% 1 0.3 0.1% : newfile : restart
  # sox -V3 "Freeze 3-Audio-1.wav" output.wav silence 1 0.50 0.1% 1 0.3 0.1% : newfile : restart

  # ffmpeg -framerate 1/1 -i %01d.jpg -r 30 3.avi
  # ffmpeg -i "concat:3.2.avi|out1.2.avi" -c copy out2.avi

  # https://github.com/ucnv/aviglitch
  # https://github.com/ucnv/aviglitch-utils
end
