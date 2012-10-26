class django {

    if !defined(Package['git']) {
        package { "git":
            ensure => installed,
        }
    }

    if !defined(Class['virtualenv']) {
        include virtualenv
    }

    if !defined(Class['supervisor']) {
        include supervisor
    }

}