glitcher
    by Roger Jungemann
    http://thefifthcircuit.com/

== DESCRIPTION:

Glitcher is a framework for making scripts which taking in "frames" of data, interact those frames, then export them back out again.

The most common frames manipulated would be sequences of still images, or a movie clip.

My purpose for making this framework was to edit the raw bytes of jpegs or mpeg video to "glitch" them up. I also want to experiment with using glitcher to "datamosh" two movies.

It uses ffmpeg and can use ImageMagick. Since Ruby isn't doing most of the heavy work, it is actually very quick.

== FEATURES/PROBLEMS:

* Break framework into four basic, distinct parts: importers, exporters, glitchers, and helpers.
* Add more import/export format options
* Add more examples of different glitchers

== SYNOPSIS:

git clone git://github.com/thefifthcircuit/glitcher.git
cd glitcher
rake install_ffmpeg && rake install_imagemagick
source bashrc
irb -rlib/glitcher2

	importer = Glitcher::Importers::JPEG.new("file.jpg")
	importer.glitchers << Glitcher::Glitchers::Munge.new
	importer.glitch
	
	Glitcher::Exporters::JPEG.new(importer.frames).call("file2.jpg")

	# another example....
	
	importer = Glitcher::Importers::Video.new("video.mp4")
	importer.glitchers << Glitcher::Glitchers::Munge.new(rand(10))
	importer.glitch
	
	Glitcher::Exporters::Video.new(importer.frames).call("video.mp4")

== REQUIREMENTS:

* FFmpeg and ImageMagick
