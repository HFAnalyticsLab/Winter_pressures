# Using R to track NHS winter pressures

This repo contains the R script used by the Health Foundation data analytics team to analyse NHS Winter Sitrep data for 2018/19.

It can be used to re-create the analysis described in the Medium blog 'Using R to track NHS winter pressures'.

## Trust-STP lookup table (version 25.2.2018)

This table was used to map hospital trusts to sustainability and transformation partnerships (STPs).


**How was this table generated?**
This table was manually created and validated, using  information related to the 2017/18 formation of 44 STPs from the [NHS England website](https://www.england.nhs.uk/integratedcare/stps/view-stps/).

**Exceptions**
- Where a trust did not appear in any list, it was allocated to the STP in whose footprint
the main site is located – this applied to four trusts in Northumberland, Tyne and Wear and North Durham STP.
- Where a trust was mentioned in more than one plan, it was allocated to the STP in whose footprint the 
main (acute) site is located – this applied to both Chesterfield Royal Hospital NHS Foundation Trust and 
Epsom And St Helier University Hospitals NHS Trust.
- Please note that STPs can change, therefore this resource should be checked before use.
