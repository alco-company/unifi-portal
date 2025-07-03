# CHANGELOG


- toggle activ
- expire 10years
- send OTP if phone found
- hide name/email 

## 0.5.1

- current_tenant from set_tenant
- search tenants
- delete all listed
- send OTP if phone found

## 0.5.0

- add login feature
- cleanup migration files
- add dashboard & navigation - sketch
- increment navigation
- refactor user and navigation

## 0.4.0

- refactor UI - tenants
- refactor UI - clients
- refactor UI - sites
- refactor UI - devices

## 0.3.0

- add upload CSV to create clients
- make tests green - lest one exemption
- add notes to clients
- hunting session bugs

## 0.2.1

- add device resource
- add clients resource

## 0.1.2

- edit site form
- testing with site created
- add sites
- make admin a scope - not part of tablenames
- add tenants
- add Kamal deployment tooling

## 0.1.1

- make all tests green on email and sms 
- validate pnr & phone and disable name/email

## 0.1.0

- rearrange form inputs and validate pnr and phone (locally only)
- test sending SMS
- setup .env.development for actually sending emails
- test send email to new user

## 0.0.1

- user test with basic happy path completed
- all tests green (basically just the happy paths)
- make testing work for outside
- creating the basic flow - sessions_controller
- add https to environments/development.rb
- use Cuprite for system tests
- respect https locally - added certificates
- initial commit - rails new heimdall -c tailwind --main
