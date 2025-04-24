## TODOS


### general
- [ ] email verification before login
- [ ] member info onboarding
- [ ] account deletion (and associated info)
- [ ] preferred name placeholder client side updates - use phoenix framework not heex
- [x] only show email in top bar if screen is wide enough
- [ ] OTP confirmation instead of link based?

### resume
- [x] uploads
- [x] max file size? (5MB)
- [x] pdf only
- [ ] bulk download for sponsors - zip stream
- [x] previewer for student
- [x] show original file name (original filename in DB - not shown to user)
- [x] set up table - member_id (index), uploaded name, original name, date uploaded, download link
- [x] delete button
- [ ] delete resume from S3 when user/resume is deleted
- [ ] better errors when file is too large or not a pdf

### admin panel
- basic auth?
- user management
- resume management
- sponsor creation
- sponsor management
- alert panel for uncorrelated payments
- paid member info aggregation

### payment integration
- endpoint to process webhook
- verification - only from flywire
- correlation with member UIN
- show members previous payments

### member login
- tamu identity linking/login - oauth

### sponsor login
- lost login help - send email to admin
- demographic charts/export
- tiers?