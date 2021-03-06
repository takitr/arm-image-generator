require 'open-uri'
require 'fileutils'
require 'digest'

class FimrwareInstaller
  FIRMWARE_DIR = 'cache/firmware'

  def backend_install
    @libdir = "#{@rootfs}/lib"

    FileUtils.rm_rf(FIRMWARE_DIR)
    FileUtils.mkdir_p(FIRMWARE_DIR)

    puts 'Downloading firmware.tar.gz'
    retry_times = 0

    # FIXME: Assume tar.gz format for now
    begin
      unless File.exist?('cache/firmware.tar.gz') && checksum_matches?
        File.write('cache/firmware.tar.gz', open(@c.config[:firmware][:url]).read)
      end
      fail 'Checksum failed to match' unless checksum_matches?
    rescue => e
      puts "Retrying download because #{e}"
      retry_times += 1
      retry if retry_times < 3
    end

    system("tar xf cache/firmware.tar.gz -C #{FIRMWARE_DIR} --strip-components=1")
    system("sudo cp -aR --no-preserve=all #{FIRMWARE_DIR}/boot/* #{@bootfs}/")
    fail 'Could not copy over firmware files!' unless $?.success?

    install_kernel_modules
  end

  def install_kernel_modules
    fail 'Failed to create modules dir!' unless system("sudo mkdir -p #{@libdir}/modules")
    fail 'Failed to create modules dir!' unless system("sudo mkdir -p #{@libdir}/firmware")
    rsync("#{FIRMWARE_DIR}/modules/", "#{@libdir}/modules/")
    rsync("#{FIRMWARE_DIR}/firmware/", "#{@libdir}/firmware/")
  end

  def rsync(src, target)
    return unless Dir.exist? src
    system("sudo rsync -r -t -p -o -g -x --delete -l -H -D --numeric-ids -s #{src} #{target}")
  end

  def checksum_matches?
    return true if @c.config[:firmware][:md5sum].nil?

    sum = Digest::MD5.file('cache/firmware.tar.gz').hexdigest
    @c.config[:firmware][:md5sum] == sum
  end

  private :backend_install
end
