`mkstatus.sh` - A tiny status page generator
--------------------------------------------

To specify services to check:

1. Create a file called `checks.tsv` somewhere. It should contains the
   following columns in order: 
   - The test you want to do. The following are valid tests to do:
      - `http`: test both IPv4 and IPv6 expecting a specific return code.
   - The `http` status code to expect. If the first field is not `http`, then
     this can be set to anything.
   - The display name of the service.
   - The address of the service.
2. Create a file called `incidents.tsv`, which should have the following
   columns in order:
   - The date of the incident (this can be any format, but I prefer the one
     produced by `date -u +'%Y-%m-%d %H:%M:%S'`).
   - A description of the incident. Unfortunately, this must all be on one
     line, so keep descriptions short and link to a blog post or security
     advisory if more explanation is needed.

Then just run ./mkstatus.sh like so:
`./mkstatus.sh checks.tsv incidents.tsv 'status.mywebsite.com' 'My Status'`

License
-------

Everything except for the Inter font (In the `font/` directory) is public
domain. The Inter font is distributed under the SIL open font license 1.1.

See `LICENSES/` for more information.

