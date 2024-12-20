# Optimal Investments in Africa's Road Network

Replication materials for the paper **Optimal Investments in Africa's Road Network**, preliminarily published as a [Kiel Working Paper](https://www.ifw-kiel.de/publications/optimal-investments-in-africas-road-network-33157/) and [World Bank Policy Research Working Paper](https://documents.worldbank.org/en/publication/documents-reports/documentdetail/099223509042435445/idu1f462ed2f121aa149d0199a913911be1bae24). Please see the [authors website](https://sebastiankrantz.com/research.html) for the latest version and publication status updates. 

**Notes**

- The code is organized sequentially, but outputs from each script that are inputs to other scripts are saved under `data/` or `results/`. Thus, each script can be executed on its own, without the need to execute earlier scripts. Also within longer scripts important intermediate results are saved. This is usually indicated at the beginning of a section.   

- Each script should be executed in a clean R session, due to global options being set in the scripts.

- Some computations can take long (1-2 days) and require significant memory (>= 30 GB). This pertains particularly to general equilibrium network optimization. I have added a note in the script whenever a computation takes long. 

- I do not loop over all possible parameter configurations reported in the general equilibrium section. The total time to obtain all results is approx. 2 months on a strong server. Thus, users should exercise discretion and only replicate GE results of interest by setting the appropriate parameter values. 

- For GE simulations install [OptimalTransportNetworks.jl](https://github.com/SebKrantz/OptimalTransportNetworks.jl) (v0.1.6 used, but later versions should work) or [OptimalTransportNetworkToolbox](https://github.com/SebKrantz/OptimalTransportNetworkToolbox) (v1.0.4b). I used the MATLAB toolbox for most simulations, but Julia for the Trans-African Network simulations in Section 6.2 of the paper. In theory both libraries are equivalent, the Julia library is just relatively new and the dual model solution and autodifferentiation system is not as efficient in Julia (yet). But all results should be replicable using the Julia library, and a corresponding Julia code is provided for simulations run in MATLAB. Going forward, the Julia library will receive further development and autodifferentiation in [JuMP](https://github.com/jump-dev/JuMP.jl) is improving. Its use is therefore encouraged and I'll fix any bugs quickly. 

- I do not use any reproducible research solution for R because I believe the packages utilized are quite robust and the specific functions employed will continue to work this way in the near future. In case parts of the code stop working at some point, users may try loading packages through [groundhog](https://groundhogr.com) setting `"2024-08-30"` as date. *Note* that I used the development version of [tmap](https://github.com/r-tmap/tmap) (v3.99.9002) not yet available on CRAN. I used R v4.3.0. The full set of R packages and versions used is:  
  ``` r
  library(fastverse)
  #> -- Attaching packages --------------------------------------- fastverse 0.3.3 --
  #> v data.table 1.15.4     v kit        0.0.17
  #> v magrittr   2.0.3      v collapse   2.0.16
  fastverse_extend(qs, sf, units, s2, sfnetworks, tidygraph, igraph, cppRouting, geodist, stplanr, tmap, 
                   osrm, ggplot2, ggstar, viridis, africamonitor, dggridR, fixest, xtable, mapview, 
                   dbscan, leaderCluster)
  #> -- Attaching extension packages ----------------------------- fastverse 0.3.3 --
  #> v qs            0.25.5        v osrm          4.1.1    
  #> v sf            1.0.16        v ggplot2       3.5.0    
  #> v units         0.8.5         v ggstar        1.0.4    
  #> v s2            1.1.6         v viridis       0.6.3    
  #> v sfnetworks    0.6.3         v africamonitor 0.2.4    
  #> v tidygraph     1.3.1         v dggridR       3.1.0    
  #> v igraph        2.0.3         v fixest        0.12.0   
  #> v cppRouting    3.1           v xtable        1.8.4    
  #> v geodist       0.0.8         v mapview       2.11.0   
  #> v stplanr       1.2.0         v dbscan        1.1.12   
  #> v tmap          3.99.9002     v leaderCluster 1.5
  #> -- Conflicts ------------------------------------------ fastverse_conflicts() --
  #> x dbscan::as.dendrogram() masks stats::as.dendrogram()
  #> x igraph::decompose()     masks stats::decompose()
  #> x fixest::fdim()          masks collapse::fdim()
  #> x tidygraph::filter()     masks stats::filter()
  #> x tidygraph::replace_na() masks collapse::replace_na()
  #> x igraph::spectrum()      masks stats::spectrum()
  #> x igraph::union()         masks base::union()
  ```
  <sup>Created on 2024-08-29 with [reprex v2.0.2](https://reprex.tidyverse.org)</sup>


**Data Availability**

All data used for this research is publically available. However, the collection, combination, and imputation of high-resolution geospatial data, except for routing information, is beyond the scope of this replication package. In particular, this research partly leverages the **Africa Infrastructure Database** constructed in my working paper [Mapping Africa's Infrastructure Potential with Geospatial Big Data and Causal ML](https://ssrn.com/abstract=4537867). This database will eventually be published alongside that paper, but is currently not public. The replication package thus starts from gridded/aggregated datasets which are provided in this package. The file `code/aggregation_example.R` is meant to give users an idea of how high-resolution point and raster data can be aggregated into discrete global grids. 

High-resolution geospatial datasets used include: 

- Open Street Map of Africa: https://download.geofabrik.de/africa-latest.osm.pbf

- Overture Maps: https://github.com/OvertureMaps/data. See also [this post](https://walker-data.com/posts/overture-buildings/) for how to access the buildings dataset in R.

- WorldPop 2020 Population (1km): https://hub.worldpop.org/geodata/summary?id=24777

- GPW4 2020 Population (1km): https://sedac.ciesin.columbia.edu/data/set/gpw-v4-population-count-rev11

- Simplemaps World Cities Database: https://simplemaps.com/data/world-cities

- Terrain Ruggedness by Diego Puga (30 arc-seconds): https://diegopuga.org/data/rugged/

- Gridded 2015 GDP PPP (5 arc-min): https://www.nature.com/articles/sdata20184, data: https://datadryad.org/stash/dataset/doi:10.5061/dryad.dk1j0

- International Wealth Index (1.6km): https://www.sciencedirect.com/science/article/abs/pii/S0305750X22002182, data: https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/5OGWYM

- GADM Country Boundaries: https://gadm.org/download_world.html

Other (non-high-resolution/non-spatial) datasets used include:

- Global International Ports (World Bank): https://datacatalog.worldbank.org/search/dataset/0038118/Global---International-Ports

- Tariff Data (World Development Indicators): Accessed through Africamonitor R API: https://africamonitor.ifw-kiel.de/ - see Topic 24. Trade Tariffs.

- WIIW NTM Database: https://wiiw.ac.at/wiiw-ntm-data-ds-2.html

- World Bank Doing Business Trading Across Borders Data: Accessed through Africamonitor R API: https://africamonitor.ifw-kiel.de/ - see Topic 25. Trade Facilitation. For domestic transport data for African economies see 'Economy Snapshots' at https://archive.doingbusiness.org/en/data.

- World Bank Road Costs Knowledge System (ROCKS) – 2018 Update: https://archive.doingbusiness.org/en/reports/thematic-reports/road-costs-knowledge-system
