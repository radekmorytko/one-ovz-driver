require 'open_vz_driver'
require 'openvz'
require 'test_utils'
require 'test/unit'
require 'flexmock/test_unit'

module OpenNebula
  class OpenVzDriverTest < Test::Unit::TestCase

    ONE_VMID = 49
    CTID = 1001
    DISK = File.absolute_path "test/resources/disk.0"
    ISO_IMG = File.absolute_path 'test/resources/disk.2'
    CACHE = "/vz/template/cache/one-#{CTID}.tar.gz"
    def setup
      # mocks
      @container = flexmock("container")
      @inventory = flexmock("inventory")
      @open_vz_data = flexmock("open_vz_data")

      @driver = OpenVzDriver.new()
    end

    def test_deploy
      # set up mocks
      @container.should_receive(:ctid).times(3).and_return(CTID)
      @container.should_receive(:create).times(1)
      @container.should_receive(:start).times(1)
      @container.should_receive(:command).times(0)

      @open_vz_data.should_receive(:disk).times(1).and_return(DISK)
      @open_vz_data.should_receive(:raw).times(1).and_return({})
      @open_vz_data.should_receive(:context).times(1).and_return(nil)
      @open_vz_data.should_receive(:vmid).times(1).and_return(ONE_VMID)

      # create img dir and contextualisation iso image link
      Dir.mkdir "/vz/one/datastores/0/#{ONE_VMID}" unless File.exists? "/vz/one/datastores/0/#{ONE_VMID}"
      File.symlink "#{ISO_IMG}", "/vz/one/datastores/0/#{ONE_VMID}/disk.2.iso"

      # assertions
      deploy_ctid = @driver.deploy(@open_vz_data, @container)
      assert_equal CTID, deploy_ctid
      assert_equal true, File.exists?(CACHE)
    ensure
      if deploy_ctid
        TestUtils.purge_template CACHE
        File.unlink "/vz/one/datastores/0/#{ONE_VMID}/disk.2.iso"
        Dir.rmdir "/vz/one/datastores/0/#{ONE_VMID}"
      end
    end

    # verify that lowest available ve_id is used
    def test_ctid
      @inventory.should_receive(:ids).times(3).and_return([680, 691, 693, 694])
      proposed = {'0' => '690', '1' => '692', '2' => '692'}

      # assertions
      proposed.each_pair do |vmid, ctid|
        assert_equal ctid, OpenVzDriver.ctid(@inventory, vmid)
      end
    end

    def test_filter_executable_files
      files = '/root/sample_cd.iso /home/radek/wallpaper.jpg /usr/local/executable.sh /tmp/yaexecutable.ksh'
      expected_files = %w(/usr/local/executable.sh /tmp/yaexecutable.ksh)

      assert_equal expected_files, OpenVzDriver.filter_executable_files(files)

      assert OpenVzDriver.filter_executable_files(nil) == []
      assert OpenVzDriver.filter_executable_files([]) == []
      assert OpenVzDriver.filter_executable_files('') == []
      assert OpenVzDriver.filter_executable_files('/home/image.jpg') == []
    end

  end
end
