# Class: cluster
#
# This module manages cluster
#
# Parameters:
#
# Sample Usage:
#
# [Remember: No empty lines between comments and class definition]
class cluster (
  $cluster_bind_interface,
  $cluster_mcastaddr
){
    $tmp_nic = "ipaddress_${cluster_bind_interface}"
    $bindnetaddr = inline_template("<%= scope.lookupvar(tmp_nic) %>")

    yumrepo {
        "clusterlabs":
            descr => 'High Availability/Clustering server technologies (epel-$releasever)',
            baseurl => 'http://www.clusterlabs.org/rpm/epel-$releasever',
            enabled => 1,
            gpgcheck => 0,
    }

    package { "corosync.$hardwaremodel":
        ensure => "installed",
        alias => "corosync",
        require => Yumrepo["clusterlabs"];
    }

    package { "pacemaker.$hardwaremodel":
        ensure => "installed",
        alias => "pacemaker",
        require => Package["corosync"];
    }

    file { "/etc/corosync/authkey":
        ensure  => present,
        mode    => 0400,
        owner   => "root",
        group   => "root",
        source  => "puppet:///modules/cluster/authkey",
        require => Package["corosync"];
    }


    file { "/etc/corosync/corosync.conf":
        ensure  => present,
        content => template("cluster/corosync.conf.erb"),
        require => Package["corosync"],
        notify  => [ Service["corosync"], Exec["load_crm_config"] ];
    }

    service { "corosync":
        enable     => true,
        ensure     => "running",
        hasrestart => true,
        hasstatus  => true,
        require    => Package["corosync"];
    }

    file { "/etc/corosync/crm.conf":
        ensure  => present,
        source  => [
            "puppet:///modules/cluster/${hostname}/crm.conf",
            "puppet:///modules/cluster/default/crm.conf",
            ],
        require => [ Package["pacemaker"], Service["corosync"] ];
    }
 
    file { "/usr/lib/ocf/resource.d/inuits/":
        ensure  => directory,
        source  => "puppet:///modules/cluster/inuits/",
        owner   => "root",
        group   => "root",
        mode    => 755,
        require => Package["corosync.$hardwaremodel"],
        recurse => true,
    }


    exec { "load_crm_config":
        command     => "crm configure load update /etc/corosync/crm.conf",
        refreshonly => true,
        subscribe   => File["/etc/corosync/crm.conf"],
        require     => File["/etc/corosync/crm.conf", '/etc/corosync/authkey'],
        path        => '/bin:/sbin:/usr/bin:/usr/sbin',
        logoutput   => true,
        environment => ['PAGER=/usr/bin/less', 'EDITOR=/bin/vi'],
        tries       => 3,
        try_sleep   => 8,
    }

}
