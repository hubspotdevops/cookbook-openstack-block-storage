require "spec_helper"

describe "cinder::volume" do
  describe "ubuntu" do
    before do
      cinder_stubs
      @chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
      @node = @chef_run.node
      @node.set["cinder"]["syslog"]["use"] = true
      @chef_run.converge "cinder::volume"
    end

    expect_runs_openstack_common_logging_recipe

    it "doesn't run logging recipe" do
      chef_run = ::ChefSpec::ChefRunner.new ::UBUNTU_OPTS
      chef_run.converge "cinder::volume"

      expect(chef_run).not_to include_recipe "openstack-common::logging"
    end

    it "installs cinder volume packages" do
      expect(@chef_run).to upgrade_package "cinder-volume"
      expect(@chef_run).to upgrade_package "python-mysqldb"
    end

    it "installs cinder iscsi packages" do
      expect(@chef_run).to upgrade_package "tgt"
    end

    it "starts cinder volume" do
      expect(@chef_run).to start_service "cinder-volume"
    end

    it "starts cinder volume on boot" do
      expect(@chef_run).to set_service_to_start_on_boot "cinder-volume"
    end

    expect_creates_cinder_conf "service[cinder-volume]"

    it "starts iscsi target on boot" do
      expect(@chef_run).to set_service_to_start_on_boot "tgt"
    end

    describe "targets.conf" do
      before do
        @file = @chef_run.template "/etc/tgt/targets.conf"
      end

      it "has proper modes" do
        expect(sprintf("%o", @file.mode)).to eq "600"
      end

      it "notifies iscsi restart" do
        expect(@file).to notify "service[iscsitarget]", :restart
      end

      it "has ubuntu include" do
        expect(@chef_run).to create_file_with_content @file.name,
          "include /etc/tgt/conf.d/*.conf"
        expect(@chef_run).not_to create_file_with_content @file.name,
          "include /var/lib/cinder/volumes/*"
      end
    end
  end
end