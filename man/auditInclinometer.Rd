\name{auditInclinometer}
\alias{auditInclinometer}
\title{Audit an inclinometer monitoring project}
\usage{
auditInclinometer(
  project.path,
  source.dir.name = .piezometerPathDefaults$source.dir.name,
  raw.dir.name = .piezometerPathDefaults$raw.dir.name,
  db.dir.name = .piezometerPathDefaults$db.dir.name,
  audit.dir.name = .piezometerPathDefaults$audit.dir.name,
  manifest = NULL
)
}
\arguments{
\item{project.path}{Project data root containing the source directory.}
\item{source.dir.name}{Project-relative client source directory.}
\item{raw.dir.name}{Project-relative parsed evidence directory.}
\item{db.dir.name}{Project-relative database output directory.}
\item{audit.dir.name}{Project-relative audit output directory.}
\item{manifest}{Optional parser manifest path; defaults to the bundled
piezometer manifest, whose \code{INC} block describes the inclinometer
CSV export structure.}
}
\description{
Runs the complete inclinometer pipeline in one call: parses the client CSV
exports under \code{<source>/INC}, builds the database products
(consolidating byte-identical surveys and recording build checks in
\code{INC.index.csv}), and audits them — source-to-raw census, raw-to-db
coverage, naming identity, header completeness, display-unit stability,
re-dated surveys, and duplicated depths — writing the findings to
\code{<audit>/log.csv} and \code{<audit>/INC.audit.csv}. The runner owns
the raw, database, and audit outputs for INC and regenerates them on each
run; source files are never modified. \code{SourcePath} cells in the
products are relative to the project root.
}
\value{
An invisible list of resolved paths: \code{project.path},
\code{source.dir}, \code{raw.dir}, \code{db.dir}, \code{audit.dir}, and
\code{log.file}.
}
