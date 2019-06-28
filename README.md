# Using R to track NHS winter pressures

This repo contains the R script used by the Health Foundation data analytics team to analyse NHS Winter Sitrep data for 2018/19.

It can be used to re-create the analysis described in the Medium blog ['Using R to track NHS winter pressures'](https://towardsdatascience.com/using-r-to-track-nhs-winter-pressures-fedcccce0b06).

## Trust-STP lookup table

This table was used to map hospital trusts to sustainability and transformation partnerships (STPs).

### How was this table generated?

We manually compiled and validated it using  information related to the **2017/18** formation of 44 STPs from the [NHS England website](https://www.england.nhs.uk/integratedcare/stps/view-stps/). While some STPs have since changed, this was the latest and most comprehensive information available, as far as we are aware.

### Special cases

The allocation of most hospital trusts to STPs was straightforward, but there were a few instances where we had to choose:

- If a trust did not appear in any STP list, it was matched according to the location of its main acute site. This was the case for the trusts City Hospitals Sunderland NHS Foundation Trust (RLN), Gateshead Health NHS Foundation Trust (RR7), Northumbria Healthcare NHS Foundation Trust (RTF) and South Tyneside NHS Foundation Trust (RE9), which we allocated to Northumberland, Tyne and Wear and North Durham STP (E54000046).

- If a trust was mentioned in more than one STP plan, it was allocated according to the location of its main acute site. This applied to  Chesterfield Royal Hospital NHS Foundation Trust (RFS) and Epsom And St Helier University Hospitals NHS Trust (RVR).

Please note that STPs change and develop over time, therefore this resource should be checked before use.

### Relevant changes since 2017/18 not reflected in this table

This information (last updated 12.03.19) is mostly based on updates from [NHS Digital](https://digital.nhs.uk/services/organisation-data-service/organisation-data-service-news-and-latest-updates/).

- STPs are evolving into [Integrated Care Systems (ICS)](https://www.england.nhs.uk/integratedcare/integrated-care-systems/)

- Plymouth Hospitals NHS Trust (RK9) is now known as University Hospitals Plymouth NHS Trust (RK9)

**April 2018**

- three STPs in the north of England (E54000045, E54000046, E54000047) merged in August 2018 to form  Cumbria and North East STP (E54000049)

**June 2018**

- Heart Of England NHS Foundation Trust (RR1) was acquired by University Hospitals Birmingham NHS Foundation Trust (RRK)

**July 2018**

- Colchester Hospital University NHS Foundation Trust (RDE) acquired Ipswich Hospital NHS Trust (RGQ), now known as East Suffolk and North Essex NHS Foundation Trust (RDE)

- Derby Teaching Hospitals NHS Foundation Trust (RTG, Derbyshire STP) acquired Burton Hospitals NHS Foundation Trust (RJF, Staffordshire and Stoke on Trent STP) to form University Hospitals of Derby and Burton NHS Foundation Trust (RTG, Joined Up Care Derbyshire STP)

**February 2019**

- Hull and East Yorkshire Hospitals NHS Trust (RWA) became Hull University Teaching Hospitals NHS Trust (RWA) 
