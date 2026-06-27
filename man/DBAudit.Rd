\name{DBAudit}
\alias{DBAudit}
\title{Run a dbAudit project}
\usage{
DBAudit(
  project.path,
  lab.dir.name = .dbauditPathDefaults$lab.dir.name,
  assay.dir.name = .dbauditPathDefaults$assay.dir.name,
  proc.dir.name = .dbauditPathDefaults$proc.dir.name,
  assay.file = NULL,
  lab.format = c("auto", "A", "B"),
  assay.format = c("auto", "A", "B"),
  tol = 5e-2
)
}
\arguments{
\item{project.path}{Project data root.}
\item{lab.dir.name}{Project-relative lab certificate directory.}
\item{assay.dir.name}{Project-relative assay directory.}
\item{proc.dir.name}{Project-relative output directory.}
\item{assay.file}{Optional assay file override.}
\item{lab.format}{Lab parser format.}
\item{assay.format}{Assay parser format.}
\item{tol}{Relative tolerance for value audits.}
}
\description{
Runs the existing dbAudit pipeline for laboratory certificates, client assay
data, and audit logs.
}
\value{
An invisible list of output paths.
}
