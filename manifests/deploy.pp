define django::deploy(
  $app_name = $title,
  $venv_path,
  $project_path,
  $git_url,
  $user,
  $gunicorn_app_module,
  $django_path = undef,
  $requirements = "requirements.txt",
  $extra_settings = undef,
  $extra_settings_source = undef,
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

  # Set django absolute path
  if $django_path {
    $django_abs_path = "${project_path}/${django_path}"
  } else {
    $django_abs_path = $project_path
  }

  # Clone APP
  exec { "git-clone ${app_name}":
    command => "git clone ${git_url} ${project_path}",
    user    => $user,
    path    => ['/usr/bin'],
    unless  => "test -d ${project_path}/.git",
    require => Package['git'],
  }

  # Create virtualenv
  virtualenv::create { $venv_path:
    user    => $user,
    require => Class['virtualenv'],
    unless  => "test -d ${venv_path}/bin",
  }

  # Create extra settings file
  if $extra_settings_source {
    file { "extra settings ${app_name}":
      ensure  => present,
      path    => "${project_path}/${extra_settings}",
      source  => $settings_source,
      owner   => $user,
      require => Exec["git-clone ${app_name}"],
      before  => Exec["syncdb ${app_name}"],
    }
  }

  # Install requirements
  virtualenv::install_requirements { "requirements ${app_name}":
    requirements => "${project_path}/${requirements}",
    venv         => $venv_path,
    user         => $user,
    require      => Virtualenv::Create[$venv_path]
  }

  # Run syncdb
  exec { "syncdb ${app_name}":
    command => 'python manage.py syncdb --noinput',
    path    => "${venv_path}/bin/",
    cwd     => $django_abs_path,
    user    => $user,
    require => Virtualenv::Install_requirements["requirements ${app_name}"],
  }

  # Run collectstatic
  if ($collectstatic) {

    exec { "collectstatic ${app_name}":
      command => 'python manage.py collectstatic --noinput',
      path    => "${venv_path}/bin/",
      cwd     => $django_abs_path,
      user    => $user,
      require => Exec["syncdb ${app_name}"],
      before  => Supervisor::App[$app_name],
    }
  }
  # Run migrate
  if ($migrate) {
    exec { "migrate ${app_name}":
      command => 'python manage.py migrate --noinput',
      path    => "${venv_path}/bin/",
      cwd     => $django_abs_path,
      user    => $user,
      require => Exec["syncdb ${app_name}"],
      before  => Supervisor::App[$app_name],
    }
  }

  # Create gunicorn conf file
  file { "gunicorn ${app_name}":
    path    => "${venv_path}/gunicorn.conf.py",
    ensure  => present,
    content => template("django/gunicorn.conf.py.erb"),
    owner   => $user,
    require => Virtualenv::Create[$venv_path],
  }

  # Configure supervisor to run django
  supervisor::app { $app_name:
    command => "${venv_path}/bin/gunicorn ${gunicorn_app_module} -c ${venv_path}/gunicorn.conf.py",
    directory => $django_abs_path,
    user => $user,
    require => File["gunicorn ${app_name}"],
  }

}