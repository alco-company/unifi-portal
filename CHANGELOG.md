# CHANGELOG

## 0.7.4

- move db to mysql (prepare for freeradius connection)

## 0.7.3

- add radius og nas (network_access_servers)
- add nas CRUD
- make nas CRUD tests green

## 0.7.2

- better error reporting on OTP
- fixing response test
- stab at unauthorize
- wrong id for client
- updating when toggled client
- wrong resource
- use either or
- doing for login what i did for api - debug
- return proper success
- return proper success on unauthorize
- update device on success
- try no help on otp input
- full on logging
- look for clients
- wait longer before redirecting
- chasing the error
- forgot to set up login api for checking authorization
- important! redirect once approved!
- head :no_content
- not double render - Turbo.action instead
- address javascript file properly
- no turbo on the OTP form!
- response depends on platform
- missing "success"
- reverse the flow
- check device and layout
- log on new
- return true if client found!
- layout is string
- send proper status
- try with do_redirect
- one more test render
- add README/TODO

## 0.7.1

- fixing diffs between api and login versions
- fixing authorize for api version
- fix sending emails with Mailersend
- fighting Mailersend unauthenticated
- fighting Mailersend unauthenticated 2 & SMS

## 0.6.3

- adjust success redirect
- trying to sync with UnifiOS on authorize
- more trying to sync
- add helper
- setting ENV to unifi(-)portal for email / SMS

## 0.6.2

- unauthorize
- always do bundle exec now!
- bundle lock --add-platform aarch64-linux
- fix search issue
- fix load_site issue
- short-circuit Site search - use site.first
- change mailersend API token and sending address
- fix site search
- fix site search 2
- fix site search 3
- testing guest session once more
- use httparty to login
- store cookie in tmp
- use mortimer.pro mailersend API key

## 0.6.1

- hide name/email
- fix Unifi API calls
- add base64

## 0.6.0

- make a site distinction between login and API controllers
- align action buttons css under heimdall_*button
- work on getting tests green
- make API work on login 
- align APIs on API-key and on login libs

## 0.5.1

- current_tenant from set_tenant
- search tenants
- delete all listed
- send OTP if phone found
- no layout on /guest/s
- ingen id på client and note on index
- toggle activ - on tenants, sites, clients, and users
- act on toggle active off on client
- show alert and notice flash'es - WIP
- error on unifi
- context behind toggle_active
- error on update
- missed setting time on authorize_guest - max 1000000 minutes
- setting production

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
