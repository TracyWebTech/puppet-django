puppet-django
=============

* A module to provides django deploy app

Requirements
=============

* virtualenv module -> https://github.com/TracyWebTech/puppet-virtualenv
* supervisor module -> https://github.com/TracyWebTech/puppet-supervisor

Usage
=============

* include the django class
```puppet
include django
```

* call define django::deploy
```puppet
django::deploy { 'app':  
      clone_path => '/path/to/clone/app',
      venv_path => '/path/to/create/virtualenv',
      git_url => 'git@github.com:host/app.git',
      user => 'user_to_install',
      gunicorn_app_module => "app.wsgi:application",
      migrate => true,
      collectstatic => true
}
```

django::deploy arguments
=============
```puppet
$venv_path # path to create virtualenv (required)
$clone_path # path to clone your repository (required)
$git_url # url of your git repository (required)
$user # user to install and run your app (required)
$gunicorn_app_module # python path to your wsgi file and your call (required)
$project_path # path in your clone repository where located django project (optional)
$requirements # path to your requirements files in your clone repository (defaults to requirements.txt)
$extra_settings # name and path relative of your project path
$extra_settings_source # puppet server path to copy your extra settings
$migrate # run migrate on deploy (defaults to false)
$collectstatic = run collectstatic on deploy (default to false)
# gunicorn configs
$bind = "0.0.0.0:8000"
$backlog = undef
$workers = "multiprocessing.cpu_count() * 2 + 1"
$worker_class = undef
$worker_connections = undef
$max_requests = undef
$timeout = undef
$graceful_timeout = undef
$keepalive = undef
$limit_request_line = undef
$limit_request_fields = undef
```