# geochem

This pipeline reproduces the current geochemical `DBAudit()` contract from R.
It does not call the CLI.

Run from the `dbAudit` repository root:

```sh
Rscript examples/scripts/geochem/runGeochem.R
Rscript examples/scripts/geochem/runGeochem.R examples/scripts/geochem/runGeochem.json
Rscript examples/scripts/geochem/runGeochem.R examples/scripts/geochem/runGeochem.project.json
```

The default JSON runs the two bundled package smoke fixtures:

```text
project/test-A
project/test-B
```

The `runGeochem.project.json` file points to the geochemical application
repository:

```text
~/projects/<PROJECT>/BV
~/projects/<PROJECT>/QV
```

Each run writes the same output family as `DBAudit()`:

```text
proc/lab.csv
proc/index.csv
proc/client.csv
proc/log.csv
```

The CLI should later dispatch this pipeline contract instead of calling
low-level helpers directly.
