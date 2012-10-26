define django::deploy(
  $app_name = $name,
  $env_path,
  $git_url,
  $user,
  $settings = "settings_local.py",
  $settings_source = undef,
  $migrate = false,
  $bind = "0.0.0.0:8000",
  $backlog = undef,
  $workers = "multiprocessing.cpu_count() * 2 + 1",
  $worker_class = undef,
  $worker_connections = undef,
  $max_requests = undef,
  $timeout = undef,
  $graceful_timeout = undef,
  $keepalive = undef,
  $limit_request_line = undef,
  $limit_request_fields = undef

) {

  # Create virtualenv
  virtualenv::create { $env_path:
    user => $user,
    require => Class['virtualenv']
  }

  # Create directory to source code
  file { "${env_path}/src/":
      ensure => directory,
      owner => $user,
      require => Virtualenv::Create[$env_path]
  }

  # Clone source
  exec { "git-clone ${app_name}":
    command => "git clone ${git_url} ${app_name}",
    cwd => "${env_path}/src/",
    require => [Package['git'], File["${env_path}/src/"]],
    user => $user,
    path => ['/usr/bin']
  }

  # Create settings file
  if $settings_source {
    file { "settings ${app_name}":
      ensure => present,
      path => "${env_path}/src/${app_name}/${settings}",
      source => $settings_source,
      owner => $user,
      require => Exec["git-clone ${app_name}"]
    }
  } else {
    file { "settings ${app_name}":
      ensure => present,
      path => "${env_path}/src/${app_name}/${settings}",
      owner => $user,
      require => Exec["git-clone ${app_name}"],
    }
  }

  # Install requirements
  virtualenv::install_requirements { "${env_path}/src/${app_name}/requirements.txt":
    virtualenv => $env_path,
    require => File["settings ${app_name}"]
  }

  # Run syncdb
  exec { "syncdb ${app_name}":
    command => 'python manage.py syncdb --noinput',
    path => "${env_path}/bin/",
    cwd => "${env_path}/src/${app_name}",
    user => $user,
    require => Virtualenv::Install_requirements["${env_path}/src/${app_name}/requirements.txt"]
  }

  # Run collectstatic
  exec { "collectstatic ${app_name}":
    command => 'python manage.py collectstatic --noinput',
    path => "${env_path}/bin/",
    cwd => "${env_path}/src/${app_name}",
    user => $user,
    require => Exec["syncdb ${app_name}"]
  }

  # Run migrate
  if ($migrate) {
    exec { "collectstatic ${app_name}": 
      command => 'python manage.py migrate --noinput',
      path => "${env_path}/bin/",
      cwd => "${env_path}/src/${app_name}",
      user => $user,
      require => Exec["syncdb ${app_name}"]
    }
  }

  # Create gunicorn conf file
  file { "${env_path}/src/gunicorn.conf.py":
    ensure => present,
    content => template("django/gunicorn.conf.py.erb"),
    owner => $user,
    require => Virtualenv::Create[$env_path]
  }

  # Configure supervisor to run django
  supervisor::app { $app_name:
    command => "${env_path}/bin/gunicorn_django -c ../gunicorn.conf.py",
    directory => "${env_path}/src/${app_name}",
    user => $user,
    require => [
      Exec["collectstatic ${app_name}"],
      File["${env_path}/src/gunicorn.conf.py"]
    ]
  }


}