Changelog
=========

## 0.6.2 11/21/2023
  * Add db.role tag

## 0.6.1 09/07/2022
  * Update for ruby 3.x compatibility
  * Splat hash when passing method expecting keyword args

## 0.6.0 07/11/2022
  * Improved pper address tag to reflect the current database when using the mysql adapter

## 0.5.2 01/24/2022
  * Fixed query tagging for empty queries

## 0.5.1 01/20/2022
  * Fixed the publishing process

## 0.5.0 01/18/2022
  * Added db.query_type and db.query_category tags
  * Added forwards compatibility code for the connection_config for rails 6.2

## 0.4.0 04/28/2020
  * Add SQL sanitizers

## 0.3.0 04/22/2020
  * Set up build pipeline with circleci and gem-publisher
  * Fixed linting issues
  * Renamed gem to `activerecord-instrumentation`
