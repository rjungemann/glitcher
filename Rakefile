task :install_ffmpeg do
  sh "curl -O ftp://ftp2.ffmpegx.com/ffmpegx/ffmpegX.dmg"
  sh "hdid ffmpegX.dmg"
  sh "cp -r /Volumes/ffmpeg*/ffmpegX.app ."
  
  device_cmd = "mount | grep /Volumes/ffmpeg | ruby -e 'puts(gets.split.first)'"
  sh "hdiutil detach `#{device_cmd}` -force"
  sh "rm ffmpeg*.dmg"
end

task :install_imagemagick do
  sh "git clone git://github.com/mxcl/homebrew.git"
  sh "cd homebrew && bin/brew install imagemagick"
end