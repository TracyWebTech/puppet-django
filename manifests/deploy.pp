define django::deploy(
  $app_name = $title,
  $venv_path,
  $clone_path,
  $git_url,
  $user,
  $gunicorn_app_module,
  $project_path = undef,
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
  if $project_path {
    $project_abs_path = "${clone_path}/${project_path}"
  } else {
    $project_abs_path = $clone_path
  }

  # Clone APP
  exec { "git-clone ${app_name}":
    command => "git clone ${git_url} ${clone_path}",
    user    => $user,
    path    => ['/usr/bin'],
    unless  => "test -d ${clone_path}/.git",
    require => Package['git'],
    timeout => 0,
  }

  # Create virtualenv
  virtualenv::create { $venv_path:
    user         => $user,
    requirements => "${clone_path}/${requirements}",
    require      => Exec["git-clone ${app_name}"],
  }

  # Create extra settings file
  if $extra_settings_source {
    file { "extra settings ${app_name}":
      ensure  => present,
      path    => "${clone_path}/${extra_settings}",
      source  => $settings_source,
      owner   => $user,
      require => Exec["git-clone ${app_name}"],
      notify  => Exec["syncdb ${app_name}"],
    }
  }

  # Run syncdb
  exec { "syncdb ${app_name}":
    command     => 'python manage.py syncdb --noinput',
    path        => "${venv_path}/bin/",
    cwd         => $project_abs_path,
    user        => $user,
    require     => Virtualenv::Create["${venv_path}"],
    subscribe   => Exec["git-clone ${app_name}"],
    refreshonly => true,
  }

  # Run collectstatic
  if ($collectstatic) {
    exec { "collectstatic ${app_name}":
      command     => 'python manage.py collectstatic --noinput',
      path        => "${venv_path}/bin/",
      cwd         => $project_abs_path,
      user        => $user,
      require     => Exec["syncdb ${app_name}"],
      before      => Supervisor::App[$app_name],
      subscribe   => Exec["git-clone ${app_name}"],
      refreshonly => true,
    }
  }
  # Run migrate
  if ($migrate) {
    exec { "migrate ${app_name}":
      command     => 'python manage.py migrate --noinput',
      path        => "${venv_path}/bin/",
      cwd         => $project_abs_path,
      user        => $user,
      require     => Exec["syncdb ${app_name}"],
      before      => Supervisor::App[$app_name],
      subscribe   => Exec["git-clone ${app_name}"],
      refreshonly => true,
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
    command   => "${venv_path}/bin/gunicorn ${gunicorn_app_module} -c ${venv_path}/gunicorn.conf.py",
    directory => $project_abs_path,
    user      => $user,
    require   => File["gunicorn ${app_name}"],
  }

}
