# ipd_metro

The Indicators of Potential Disadvantage (IPD) are a resource for staff, member governments, planning partners, and the general public in the DVRPC Region to incorporate equity concerns in their work and research. Because the IPD measures are computed from publicly-available data, they can be computed the same way for any study area in the U.S.

These scripts extend the original IPD analysis to consider all Metropolitan Statistical Areas (MSAs) in the U.S. at the census tract level. Here's a picture of what the results look like at the census tract level for the City of Philadelphia:

![alt text][philadelphia-tracts]

[philadelphia-tracts]: ../master/figures/phila_tract.png "Map of Philadelphia Tracts by IPD Score"

And when aggregated to the county for the New York-Newark MSA:

![alt text][nyc-counties]

[nyc-counties]: ../master/figures/nyc_county.png "Map of NYC MSA Counties by IPD Score"

## Outputs

- [`geo.csv`](../master/outputs/geo.csv) is all the county FIPS codes by MSA downloaded from NBER and formatted for use with the Census Bureau API.
- [`ipd.csv`](../master/outputs/ipd.csv) is the tract-level IPD score for all census tracts in all MSAs in `geo.csv`.
- [`ipd.shp`](../master/outputs/ipd.shp) is a shapefile showing IPD scores aggregated to the county level.
- [`mean_by_county.csv`](../master/outputs/mean_by_county.csv) and [`mean_by_metro.csv`](../master/outputs/mean_by_county.csv) are IPD scores aggregated to the county and MSA levels, respectively.

## How to run things, basically

1. Open `ipd_metro.Rproj` and run [`geo.R`](../master/geo.R) to get MSA county FIPS codes.
2. Run [the main script](../master/script.R) to compute IPD scores at the census tract level.
