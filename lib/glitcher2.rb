# pick a random item from an array or a range
class Array; def pick; self[rand(self.size)] end end
class Range; def pick; self.min + rand(self.max - self.min) end end

# swap two chars in a string
class String; def swap i, j; self[i], self[j] = self[j], self[i]; self end end

module Glitcher
  class Magick
    def crop infile, outfile, x, y, gravity
      `convert #{infile} -crop #{x}x#{y} -gravity #{gravity} #{outfile}`
    end

    def splice infile, outfile, x, y, gravity
      `convert #{infile} -splice #{x}x#{y} -gravity #{gravity} #{outfile}`
    end

    def composite top_infile, bottom_infile, outfile, x, y
      `convert #{top_infile} -geometry #{signed_n x}#{signed_n y}`
    end
    
    private
    
    def signed_n n; "#{n > 0 ? '+' : '-'}#{n}" end
  end
  
  module Importers
    class AbstractImporter
      attr_accessor :frames, :glitchers
      
      def initialize; @frames, @glitchers = [], [] end
      
      def glitch
        @glitchers.each do |glitcher|
          @frames = @frames.map { |frame| glitcher.call(frame) }
        end
        self
      end
    end
    
    class JPEG < AbstractImporter
      def initialize infile
        super()
        @frames = [File.read(infile).unpack("H*").first]
      end
    end
    
    class Video < AbstractImporter
      def initialize infile
        super()
        @frames, @tmpdir = [], "tmp"
        
        `mkdir #{@tmpdir}` unless File.exists? @tmpdir
        `ffmpeg -i #{infile} #{@tmpdir}/%d.jpg`
        
        i = 1
        while File.exists?("#{@tmpdir}/#{i}.jpg")
          @frames << File.read("#{@tmpdir}/#{i}.jpg").unpack("H*").first
          i += 1
        end
      end
    end
  end
  
  module Glitchers
    class AbstractGlitcher
      attr_accessor :frames
      
      def call frame; frame end
    end
    
    class Munge < AbstractGlitcher
      def initialize times = 1
        @delineator = 'ffc4' # only modify data delineated by the symbol
          # indicating a new "huffman table" is being defined
          # http://en.wikipedia.org/wiki/JPEG
        @times = times
      end
      
      def call frame
        @times.times { frame[rand(frame.size)] = rand(16).to_s(16) }
        frame
      end
    end
  end
  
  module Exporters
    class AbstractExporter
      def initialize frames; @frames = frames end
      def call outfile; end
    end
    
    class JPEG < AbstractExporter
      def initialize frames; @frames = frames end
      
      def call outdir
        @frames.each_with_index do |frame, i|
          File.open("#{outdir}/#{i}.jpg", "w") { |f| f.puts([frame].pack("H*")) }
        end
      end
    end
    
    class Video < AbstractExporter
      def initialize frames; @frames = frames end
      
      def call outdir
        puts 
        
        @frames.each_with_index do |frame, i|
          File.open("#{outdir}/#{i + 1}.jpg", "w") { |f| f.puts([frame].pack("H*")) }
        end
        
        `ffmpeg -f image2 -i #{outdir}/\%d.jpg #{outdir}/glitcher.mp4`
      end
    end
  end
end

#importer = Glitcher::Importers::JPEG.new(ARGV[0])
#importer.glitchers << Glitcher::Glitchers::Munge.new
#importer.glitch
#
#Glitcher::Exporters::JPEG.new(importer.frames).call(ARGV[1])

#importer = Glitcher::Importers::Video.new(ARGV[0])
#importer.glitchers << Glitcher::Glitchers::Munge.new(rand(10))
#importer.glitch
#
#Glitcher::Exporters::Video.new(importer.frames).call(ARGV[1])