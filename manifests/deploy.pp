define django::deploy(
  $app_name = $name,
  $venv_name = $name,
  $project_path,
  $clone_path = "src",
  $git_url,
  $user,
  $settings = "settings_local.py",
  $settings_source = undef,
  $requirements = "requirements.txt",
  $migrate = false,
  $collectstatic = false,
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

  if $clone_path == "" {
    $source_path = $project_path
  } else {
    $source_path = "${project_path}/${clone_path}"
  }

  # Clone APP
  exec { "git-clone ${app_name}":
    command => "git clone ${git_url} ${source_path}",
    user    => $user,
    path    => ['/usr/bin'],
    unless  => "test -d ${source_path}",
    require => Package['git'],
  }

  # Create virtualenv
  virtualenv::create { $venv_name:
    user    => $user,
    project => $project_path,
    require => Class['virtualenv'],
  }

  # Create settings file
  if $settings_source {
    file { "settings ${app_name}":
      ensure  => present,
      path    => "${source_path}/${settings}",
      source  => $settings_source,
      owner   => $user,
      require => Exec["git-clone ${app_name}"]
    }
  } else {
    file { "settings ${app_name}":
      ensure  => present,
      path    => "${source_path}/${settings}",
      owner   => $user,
      require => Exec["git-clone ${app_name}"],
    }
  }

  # Install requirements
  virtualenv::exec { "requirements ${app_name}":
    virtualenv => $venv_name,
    user       => $user,
    command    => "pip install -r ${source_path}/${requirements}",
    require    => File["settings ${app_name}"],
  }

  # Run syncdb
  virtualenv::exec { "syncdb ${app_name}":
    virtualenv => $venv_name,
    command    => 'python ${source_path}/manage.py syncdb --noinput',
    user       => $user,
    require    => Virtualenv::Exec["requirements ${app_name}"],
  }

  # Run collectstatic
  if ($collectstatic) {
    virtualenv::exec { "collectstatic ${app_name}":
      virtualenv => $venv_name,
      command    => 'python ${source_path}/manage.py collectstatic --noinput',
      user       => $user,
      require    => Virtualenv::Exec["syncdb ${app_name}"],
      before     => Supervisor::App[$app_name],
    }
  }
  # Run migrate
  if ($migrate) {
    virtualenv::exec { "migrate ${app_name}": 
      virtualenv => $venv_name,
      command    => 'python ${source_path}/manage.py migrate --noinput',
      user       => $user,
      require    => Virtualenv::Exec["syncdb ${app_name}"],
      before     => Supervisor::App[$app_name],
    }
  }

  # Create gunicorn conf file
  file { "gunicorn ${app_name}":
    path    => "${project_path}/gunicorn.conf.py",
    ensure  => present,
    content => template("django/gunicorn.conf.py.erb"),
    owner   => $user,
    require => Virtualenv::Create[$venv_name]
  }

  # Configure supervisor to run django
  supervisor::app { $app_name:
    command => "\$HOME/.virtualenvs/${venv_name}/bin/gunicorn_django -c ../gunicorn.conf.py",
    directory => "${source_path}",
    user => $user,
    require => File["gunicorn ${app_name}"],
  }


}