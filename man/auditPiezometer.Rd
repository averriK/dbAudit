\name{auditPiezometer}
\alias{auditPiezometer}
\title{Audit a piezometer monitoring project}
\usage{
auditPiezometer(
  project.path,
  source.dir.name = .piezometerPathDefaults$source.dir.name,
  raw.dir.name = .piezometerPathDefaults$raw.dir.name,
  db.dir.name = .piezometerPathDefaults$db.dir.name,
  audit.dir.name = .piezometerPathDefaults$audit.dir.name,
  id = c("PCG", "PCV"),
  manifest = NULL
)
}
\arguments{
\item{project.path}{Project data root containing the source directory.}
\item{source.dir.name}{Project-relative client source directory.}
\item{raw.dir.name}{Project-relative parsed evidence directory.}
\item{db.dir.name}{Project-relative database output directory.}
\item{audit.dir.name}{Project-relative audit output directory.}
\item{id}{Instrument families to process: \code{"PCG"} (Casagrande),
\code{"PCV"} (vibrating wire), or both.}
\item{manifest}{Optional parser manifest path; defaults to the bundled
piezometer manifest.}
}
\description{
Runs the complete piezometer pipeline in one call: parses the client
workbooks under the source directory, gates every observation before it
enters the database (the approved repairs are persisted and every row that
does not enter as-is is recorded with its reason in
\code{<audit>/<ID>.reject.csv}), builds the database products, and audits
them. The runner owns the raw, database, and audit directories for the
selected ids and regenerates them on each run; source files are never
modified. \code{SourcePath} cells in the products are relative to the
project root.
}
\value{
An invisible list of resolved paths: \code{project.path},
\code{source.dir}, \code{raw.dir}, \code{db.dir}, \code{audit.dir}, and
\code{log.file}.
}
