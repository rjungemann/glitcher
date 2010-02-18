FFMPEG_PATH = ENV['FFMPEG_PATH'] || "#{File.dirname(__FILE__)}/ffmpeg"

# pick a random item from an array or a range
class Array; def pick; self[rand(self.size)] end end
class Range; def pick; self.min + rand(self.max - self.min) end end

# swap two chars in a string
class String; def swap i, j; self[i], self[j] = self[j], self[i]; self end end

module Glitcher
  class JPEG
    def self.hex_from_file infile; File.read(infile).unpack("H*").first end
    def self.from_file infile; JPEG.new JPEG.hex_from_file(infile) end
    
    def initialize input
      @input = input
      @delineator = 'ffc4' # only modify data delineated by the symbol
        # indicating a new "huffman table" is being defined
        # http://en.wikipedia.org/wiki/JPEG
      @indices = []

      while(@indices.size < 1 || @indices.last != nil)
        first = @input.index(@delineator, @indices.size < 1 ? 0 : @indices.last.max)
        range = first ? (first..(first + @delineator.size)) : nil

        @indices << range
      end

      @indices.pop if @indices.last.nil?

      @minimum, @maximum = @indices.first.max, @indices.last.min
      @allowed_indices = []

      @indices.each_with_index do |index, i|
        next if i < 1
        @allowed_indices << ((@indices[(i - 1)].max + 1)..(@indices[i].min) - 1)
      end
    end

    def custom_munge n = 1, &block; n.times { |i| yield self, @input } end

    def munge n = 1
      n.times { @input[rand(@input.size)] = rand(16).to_s(16) }
      self
    end

    def munge_swap n = 1
      n.times {
        first = @allowed_indices.pick.pick
        second = first
        second = @allowed_indices.pick.pick while first == second

        @input.swap(first, second)
      }
      self
    end

    def munge_swap_adjacent n = 1
      n.times { i = @allowed_indices.pick.pick; @input.swap(i, i + 1) }
      self
    end

    def to_file outfile
      File.open(outfile, "w") { |f| f.puts([@input].pack("H*")) }
      self
    end

    def file_sequence outdir, n = 1, &block
      n.times { |i| yield self, @input; self.to_file "#{outdir}/#{i}.jpg" }
      self
    end
    
    def video_sequence outdir, n = 1, &block
      self.file_sequence outdir, n, &block
      `#{FFMPEG_PATH} -f image2 -i #{outdir}/%d.jpg #{outdir}/glitcher.mp4`
      self
    end
  end
end

Glitcher::JPEG.from_file(ARGV[0]).video_sequence(ARGV[1], 100) do |g, s|
  g.munge(2)
end