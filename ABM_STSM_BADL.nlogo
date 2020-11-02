extensions [gis csv]
breed [bison a-bison]
breed [springs spring]
bison-own [thirst]
patches-own [npp
             biomass
             biomass_removed
             min-spring-dist
             spring-proximity-index
             stateclass grazepref
             grazed
             bnp
             graze-destination
             enough-biomass]
globals [ growing-season
          rainy-season
          dm-need
          dm-need-d10
          bison-cnt
          t1
          year
          biomass-dataset
          bio_rem-dataset
          bnp-dataset
          stateclass-layer
          springs-boundary
          ]


; ****************
; SETUP
; ****************

to setup
  clear-all
  file-close-all
  setup-parms
  setup-gis
  setup-patches
  setup-agents
  setup-distances
  reset-ticks
end

to setup-parms
  set year 1
  set dm-need 28.0                                ; Based on average daily consumption (lb) of vegetation weighted according to seasonal consumption values (original source Feist 2000)
  set dm-need-d10 ( dm-need / 10.0)
end

to setup-gis
  gis:load-coordinate-system (word "_dataDir_/template.prj")
  set bnp-dataset gis:load-dataset "_dataDir_/planzone_crntbsn_100.asc"
  set stateclass-layer gis:load-dataset "_inputPath_" ;load stateclass raster
  gis:set-world-envelope gis:envelope-of bnp-dataset
  gis:apply-raster bnp-dataset bnp
  gis:apply-raster stateclass-layer stateclass
  ask patches [
    ifelse bnp = 3
    [ set bnp 1   ]
    [ set bnp -99 ]  ;Set "No Data" values to -99
 ]
  ask patches [
    ifelse stateclass < 0
    [ set stateclass -99]
    [ ]
  ]
   ask patches [
   ifelse stateclass = -99
    [set biomass -99]
    [set biomass 0]
  ]
  ask patches [
    ifelse stateclass < 0
    [set biomass_removed -99]
    [set biomass_removed 0]
  ]
   ask patches [
    set npp 0
    set grazed 0   ; tracks wether or not a patch was grazed in previous timestep
  ]
end


to setup-patches
  ask patches [ set pcolor black ]
    ask patches [
      if stateclass = 7 or stateclass = 10 or stateclass = 16
      [ set pcolor orange
        set grazepref random-float (.25 - .05) + .05
    ]
      if stateclass = 17
      [ set pcolor yellow
        set grazepref random-float (.55 - .25) + .25
    ]
      if stateclass = 1 or stateclass = 2 or stateclass = 3 or stateclass = 8 or stateclass = 9 or stateclass = 11 or stateclass = 12 or stateclass >= 18
      [ set pcolor green
        set grazepref random-float (1 - .55) + .55
      ]
    ]
;; NPP and initial biomass set manually based on estimated 1960 values (average year preceded by average years)
    ask patches [
     If stateclass = 1 [set npp 17.56981992 set biomass 3513.963984]
     If stateclass = 2 [set npp 18.66123115 set biomass 3732.24623]
     If stateclass = 3 [set npp 14.4340039 set biomass 2886.800779]
     If stateclass = 7 [set npp 13.23971605 set biomass 2647.943209]
     If stateclass = 8 [set npp 20.87896267 set biomass 4175.792535]
     If stateclass = 9 [set npp 14.06385282 set biomass 2812.770563]
     If stateclass = 10 [set npp 8.45137149 set biomass 1690.274298]
     If stateclass = 11 [set npp 8.646381593 set biomass 1729.276319]
     If stateclass = 12 [set npp 26.77990229 set biomass 5355.980458]
     If stateclass = 16 [set npp 7.955999851 set biomass 1591.19997]
     If stateclass = 17 [set npp 7.436820868 set biomass 1487.364174]
     If stateclass = 18 [set npp 9.887571506 set biomass 1977.514301]
     If stateclass = 19 [set npp 19.39727984 set biomass 3879.455967]
     If stateclass = 20 [set npp 15.57310272 set biomass 3114.620545]
     If stateclass = 21 [set npp 26.69058736 set biomass 5338.117471]
    ]

;;there has to be at least enough biomass to meet hourly forage requirement plus 25% loss of biomass due to trampling, defacation, and wildlife
;;which is calculated as total annual NPP (npp values * 200 days) spread over all potential annual grazing hours (10 hr/day for 365 days/year)
    ask patches [
     ifelse (biomass >= (dm-need-d10 + (0.25 * (npp * 200)/(365 * 10))))
       [set enough-biomass true]
       [set enough-biomass false]
    ]
end


to setup-agents
create-springs spring-cnt [
    file-open(word "_dataDir_/springs_locations_out.txt")
    setxy file-read file-read
    set color blue
    set size 4.5
  ]
  file-close

  set-default-shape bison "cow"

  create-bison bison-num [
    file-open "locations_in.txt"
    setxy file-read file-read
    set color brown
    set size 6.5
  ]
  file-close
end


to setup-distances
  ask patches [
    set min-spring-dist min [ distance myself ] of springs
  ]
  set t1 max [ min-spring-dist ] of patches
  ask patches [
    set spring-proximity-index ( 1.0 - ( min-spring-dist / t1 ) )
    if bnp != 1 [set spring-proximity-index -99]
  ]
end

;****************
; GO
;****************
to go                                          ; ticks represent a day, and are reset each year.  Bison forage for 10 hours/day
  let hour 0
    ask patches [                              ; growing season defined as Apr 15-Oct 31 and rainy season as Apr 15 - Jul 15
     ifelse (ticks >= 166 and ticks < 257)     ; starting model at end of growing season (Nov 1, julian=305, ticks=1) and rainy season begins Apr 15 (Julian=105, ticks=166) and goes through Jul 14 (julian=195, ticks=256)
       [set rainy-season true]
       [set rainy-season false]
     ifelse (ticks >= 166)                     ; growing season begins tick=166 (Apr 15, Julian=105) and goes through Oct 31 (julian=304, ticks=365); 200 days
      [set growing-season true]
      [set growing-season false]
    ifelse ( growing-season )
      [ grow-grass ]
      [ decay ]
    ]

  set hour 0

  while [ hour < 10 ]
   [ do-hour
    set hour (hour + 1)
   ]

  tick

  if ticks = 365 [
    file-open "locationsNew.txt"
    ask bison[
     file-write xcor file-write ycor
     ]
    file-close
  ]

  if ticks = 366 [
  New-Year
  ]

end


to do-hour
  ask patches [
    ifelse (biomass >= (dm-need-d10 + (0.25 * (npp * 200)/(365 * 10))))              ; there has to be at least enough biomass to meet hourly forage requirement plus 25% loss of biomass due to trampling, defacation, and wildlife
      [set enough-biomass true]                                                      ; which is calculated as total annual NPP (npp values * 200 days) spread over all potential annual grazing hours (10 hr/day for 365 days/year)
      [set enough-biomass false]
  ]

  let turn1 0.05
  let turnangle 90

  ask bison [
   let rnd random-float 1.0
   set graze-destination max-one-of (patches in-cone 2 120 with [enough-biomass = true]) [grazepref]
   if graze-destination = nobody [
     right 120
     set graze-destination max-one-of (patches in-cone 2 120 with [enough-biomass = true]) [grazepref]]
   if graze-destination = nobody [
     right 120
     set graze-destination max-one-of (patches in-cone 2 120 with [enough-biomass = true]) [grazepref]]
   if graze-destination = nobody [
     set graze-destination min-one-of (patches with [enough-biomass = true]) [distance myself]]   ; If turning doesn't work, then bison is moved to nearest patch with stateclass value. Added to prevent bison getting stuck

   if (rainy-season = true) [
     ifelse (enough-biomass = true)
     [if rnd > .95 [
        face graze-destination
        forward 1
        ]
     ]
     [face graze-destination
      forward 1
     ]
    set thirst random-float maximum-thirst
    ]

    if (rainy-season = false) [
      ifelse (thirst >= maximum-thirst)
        [let t4 max-one-of neighbors [ spring-proximity-index ]
         face t4
         if rnd < turn1 [
           let rnd3 random turnangle - ( turnangle / 2.0 )
           right rnd3
         ]
         ifelse patch-ahead 1 = nobody or [ bnp ] of patch-ahead 1 != 1
           [right turnangle]
           [forward 1]
        ]
        [ifelse (enough-biomass = true)
           [if rnd > .95 [
            face graze-destination
            forward 1
            ]
           ]
           [face graze-destination
            forward 1
           ]
         ]
    set thirst ( thirst + 0.01 )
    ]

    if any? springs-here
      [ set thirst 0 ]

    if stateclass > 0 and enough-biomass = true
      [set biomass ( biomass - (dm-need-d10 + (0.25 * (npp * 200)/(365 * 10))))
       set biomass_removed (biomass_removed + (dm-need-d10 + (0.25 * (npp * 200)/(365 * 10))))
       set grazed (grazed + 1)
      ]
    if stateclass > 0 and enough-biomass = false [
      set biomass random-float 1.0
    ]
  ]
end


to grow-grass
  If stateclass > 0 [
    set biomass biomass + npp
  ]
end


to decay
  if biomass > 0
  [set biomass (3300 /(1 + (0.005 * (1.055 ^ (ticks)))))]      ; distributes decay over the course of the non-growing season period (165 days) using logistic function; numerator is estimate of annual max mean live biomass
end


to New-Year
    reset-ticks
    set year ( year + 1 )
    ask patches [
      if stateclass > 0 [
        set grazed 0
        set biomass_removed 0
      ]
      if stateclass = 7 or stateclass = 10 or stateclass = 16   ; update grazing prefernce values (if stateclass has changed due to ST-Sim)
        [set pcolor orange
        set grazepref random-float (.25 - .05) + .05
        ]
      if stateclass = 17
        [set pcolor yellow
        set grazepref random-float (.55 - .25) + .25
        ]
      if stateclass = 1 or stateclass = 2 or stateclass = 3 or stateclass = 8 or stateclass = 9 or stateclass = 11 or stateclass = 12 or stateclass >= 18
        [set pcolor green
         set grazepref random-float (1 - .55) + .55
        ]

; NPP updated in case stateclass has changed
     If stateclass = 1 [set npp 17.56981992]
     If stateclass = 2 [set npp 18.66123115]
     If stateclass = 3 [set npp 14.4340039]
     If stateclass = 7 [set npp 13.23971605]
     If stateclass = 8 [set npp 20.87896267]
     If stateclass = 9 [set npp 14.06385282]
     If stateclass = 10 [set npp 8.45137149]
     If stateclass = 11 [set npp 8.646381593]
     If stateclass = 12 [set npp 26.77990229]
     If stateclass = 16 [set npp 7.955999851]
     If stateclass = 17 [set npp 7.436820868]
     If stateclass = 18 [set npp 9.887571506]
     If stateclass = 19 [set npp 19.39727984]
     If stateclass = 20 [set npp 15.57310272]
     If stateclass = 21 [set npp 26.69058736]

    ]

  ask bison [
    set thirst random-float maximum-thirst
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
353
10
1301
994
-1
-1
5.0
1
10
1
1
1
0
0
0
1
0
187
0
194
0
0
1
ticks
30.0

BUTTON
6
10
69
43
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
177
14
240
47
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
9
63
66
108
Year
year
17
1
11

BUTTON
87
12
150
45
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
73
63
130
108
Day
ticks
17
1
11

SLIDER
7
216
179
249
spring-cnt
spring-cnt
0
20
4.0
1
1
NIL
HORIZONTAL

SLIDER
8
122
180
155
bison-num
bison-num
0
2000
520.0
1
1
NIL
HORIZONTAL

MONITOR
143
61
220
106
Bison
count bison
17
1
11

SLIDER
8
168
180
201
Maximum-thirst
Maximum-thirst
0
6
5.0
0.1
1
NIL
HORIZONTAL

@#$#@#$#@
# ODD PROTOCOL
##1. Overview
###1.1. Purpose
The purpose of this agent-based model (ABM) is to provide a stylized representation of bison movement and grazing to demonstrate the utility of coupling an ABM with a state-and-transition simulation model (STSM) of vegetation dynamics. The model was initially based on a dry- versus wet-season cattle grazing model developed by Boone and Galvin (2014), which is available on the NetLogo Community Models webpage (http://ccl.northwestern.edu/netlogo/models/community/Growth_Used_in_Chapter_and_Distributed).

###1.2. Entities, state variables, and scales
This model is comprised of three entities: bison, springs, and patches. The patches, or cells, represent local vegetation characteristics and collectively produce a dynamic landscape. The landscape is an approximation of the vegetation within the previous bison range of Badlands National Park. Bison are mobile agents that interact with the landscape. Springs are static, point locations that represent water sources for bison.

The modeled landscape is approximately 90,589 acres, and is comprised of 36,660 pixels with 2.47 acre resolution. The world is bounded.

One timestep represents one day, but the model implements bison movement and grazing on an hourly basis for 10 hours each day. The model also tracks years.

###1.3. Process overview and scheduling
The model is comprised of a setup procedure, and several repeating submodels within the run procedure. For standalone ABM runs, vegetation state class is static. When coupled to the STSM, state class and associated parameters (grazing preference, NPP) are updated annually. Bison movement decisions are described below.

##2. Design Concepts
###2.1. Basic principles
By running this ABM independently and in conjunction with a separate model of landscape change, the model is intended to illustrate the influence of dynamic agents on the environment, as well as a dynamic environment on agents.

###2.2. Emergence
Patterns of biomass removal (and state class changes when coupled to the STSM) may vary in unexpected ways given that bison movement is driven by several time-varying environmental properties and agent characteristics.

###2.3. Adaptation & Objectives
Individual agents adapt to changing conditions through decisions that account for variation in their environment (grazing preference) and individual characteristics (thirst), and by altering their decision rules over time (seasonally). They seek the highest quality vegetation (as approximated by grazing preference values) available that also allows them to meet forage requirements, and to keep thirst below a given threshold. These modeled behaviors are implicitly assumed to maximize fitness, but fitness is not measured.

###2.4. Learning & Prediction
Agents do not `learn` (i.e., change their adaptive traits over time as a result of prior experience Grimm et al. 2010) or predict future conditions.

###2.5. Sensing
Bison sense variation in vegetation composition and distance to water sources. This drives movement decisions, depending upon season.

###2.6. Interaction
Bison do not interact, except indirectly through grazing, which affects biomass available to other bison.

###2.7. Stochasticity
The model is stochastic due to random variation in grazing preference (patch values are drawn from state class-specific random uniform distributions), thirst (reset to a random number between zero and maximum thirst during the wet-season), movement (even in instances where there is sufficient biomass and grazing preference for an agent to remain on a patch, there is a 5% chance they will move), and the direction of thirst-driven movement (deviation from a direct path to springs).

###2.8. Collectives
Agents do not belong to any collective entity or aggregation.

###2.9. Observation
Spatial data on biomass, grazing, and biomass removal are tracked by the model in order to identify patterns in these variables, and provide necessary input data for the STSM. These data are tracked on an hourly timestep and output on an annual basis.

##3. Details
###3.1. Initialization
The initial landscape is setup using raster datasets for the national park boundary and state classes. Grazing preference is then assigned to each patch based on state class. The locations of four springs were randomly generated within the study area boundary. These locations remain the same across iterations and over time (i.e., spring locations were randomized once across all model runs). 520 bison are initialized in 10 clusters (loosely representing an initial non-random spatial distribution akin to herds), which are spatially randomized and are static iteration-to-iteration.

Upon setup of the landscape and agents, each patch determines its minimum spring distance and spring proximity index. Similar to Boone and Galvin (2014), each patch calculates the distance to the nearest spring (min-spring-dist), and then standardizes this value on a 0 to 1 scale using the maximum min-spring-dist for all patches as:

spring-proximity-index = 1.0 - (min-spring-dist/(maximum[min-spring-dist]))

Each patch also determines and tracks if it has enough biomass to meet the hourly bison forage intake requirement plus an additional 25% of NPP to account for trampling and defecation (consistent with Miller et al. 2017), which is calculated as total annual NPP (NPP/day * 200 days) spread over all potential annual grazing hours (10 hr/day for 365 days/year).

The model is initialized at the end of the growing season (November 1).

###3.2. Input data
Bison range boundary: raster layer of the approximate boundary of the previous bison range of Badlands National Park. The bison range was recently expanded, but only after modeling was complete, hence the use of the previous bison range boundary for this work.
Initial state class raster: raster layer of vegetation state class based on initial raster data from Miller et al. 2017, but with several modifications: removed thistle and encroached state classes (thistle and encroached cells were reassigned to another state class according to the proportional areas of the remaining landscape), increased resolution to 100m in order to provide more patches, restricted to previous bison range in the north unit of Badlands National Park.

Grazing preference distributions: distributions that represent the relative preference of bison for a given vegetation state class that were derived from a single expert\'s estimates in the Miller et al. 2017 dataset. This expert was the only one to specify grazing preferences for bison (rather than cattle). All values were standardized to range from 0 to 1. Individual patch values were drawn from random uniform distributions whereby state class specific minima and maxima were set based on state class.

Number of bison: total number of bison was based on the desired herd size for Badlands NP (600-700, Department of the Interior 2014), which was adjusted because the modeled landscape accounts for 80% of the grazeable area in the previous bison range.

NPP: state class-specific daily net primary production values based on annual NPP values from 1960 (which was classified as an average year, preceded by average year according to methods described in Miller et al. 2017).

Initial biomass: state class-specific values for end-of-growing-season aboveground biomass based on NPP values.

Forage requirements -- Daily bison forage intake (dm-need, 28 lb/day) was calculated based on animal weight from Licht (2016) and dry forage matter intake estimates for spring and summer/fall from Feist (2000). Following Feist (2000), we assumed bison dry forage matter intake was 2.6% of their body weight (1,150 lb). To simplify the model, we did not vary consumption for the dormant season, and a single season-long daily forage intake value was calculated as an average across spring and summer/fall seasons weighted by the number of days in each season. Bison graze 10 hours per day, and hourly forage intake (dm-need-d10) was calculated as the daily intake divided by 10.

Several parameters were estimated and calibrated (rather than based on published information):
rate of thirst accumulation = 0.01/hr
maximum-thirst = 5.0 (50 days to reach maximum-thirst if initial thirst is 0)
cone of `vision` = 120 degrees
sensing distance = 2 patches (656 ft)

###3.3. Submodels
The landscape submodel is comprised of vegetation growth and decomposition. Vegetation composition is updated annually when the ABM is coupled to an STSM.

Vegetation growth occurs only during the growing season (defined as April 15-October 31, ticks 165-365), and consists of biomass accumulation according to state class-specific NPP values (described above).

Decomposition occurs when it is not the growing season (ticks 0-165) according to an inverse logistic function where patch biomass is set as:
biomass = 3300 /(1 + (0.005 * (1.055 ^ ticks)))

Decay parameters were estimated and calibrated in order to produce a biomass curve that approached 0 mean biomass at the end of the model year.

Patches track whether or not they have at least enough biomass to meet the hourly forage requirement for a single bison plus biomass removed due to trampling, defecation, and other wildlife. This additional hourly biomass removal is calculated as 25% of the total annual NPP (npp x 200 days/yr) spread over all potential grazing hours in a year (10 hr/day for 365 days/year), which assumes that 25% of a patch\`s annual NPP can be removed by factors other than direct intake, even if the same patch is grazed continuously throughout the year. In other words, enough-biomass was defined as `true` if a cell has biomass that is greater than or equal to:
dm-need-d10 + (0.25 * (npp * 200)/(365 * 10))

Bison accumulate thirst, make movement decisions, and graze hourly for 10 hours per day. During the rainy season (April 15-July 15, ticks 165-256), thirst is set as a random number below maximum-thirst to provide variation when dry-season begins. During the dry season, thirst accumulates hourly by adding 0.01 to thirst.

Bison movement decisions are season-dependent and driven by thirst, grazing preference, daily forage requirements, and the boundary of the bison range. Grazing preferences, forage requirements, and the boundary of the bison range are described above (see Input Data above). During the dry season when thirst reaches maximum-thirst, bison movement decisions are driven by the location of the nearest spring. Bison move to the neighboring patch with the lowest distance to a spring (maximum spring-proximity-index), with a 5% chance that bison will deviate from their determined path by 45 degrees to the left or right; in this way, bison do not deterministically follow a straight line to water sources. During the rainy season and during the dry season when thirst is below maximum-thirst, grazing preferences and biomass availability drive grazing decisions. Bison identify the patch with the highest grazing preference and enough biomass to meet forage requirements within a distance of 2 patches and a 120 degree cone of `vision`. If no such patch is available, the bison turns 120 degrees and re-evaluates potential destination patches. A bison will repeat this process until it identifies a suitable destination patch or returns to its original heading. If a bison returns to its original heading without identifying a destination patch, it will set the nearest patch with sufficient biomass as its destination patch (this avoids bison getting trapped in areas with insufficient forage). Before moving to its destination patch, bison evaluate if there is sufficient biomass on its current patch. If not,  bison will move to the destination patch. If there is sufficient biomass on a bison\'s current patch, it will stay, but there is a 5% chance that it will still move to the destination patch.

Once bison decide to move to a new patch or stay on their current patch, they graze. Each time a bison grazes, several patch variables are updated: 1) the number of times the patch has been grazed that year (grazed) is increased by one; 2) biomass (biomass) is reduced by the average hourly forage intake of an individual bison plus 25% of hourly npp (this is the same as the calculation for enough-biomass above); and 3) the amount of biomass removed in that year (biomass_removed) is increased by the same amount that is subtracted from patch biomass. If a bison reaches a spring location, thirst is set to zero.

At the end of each year, patch variables for tracking the amount of biomass removed and the number of times grazed are reset to zero. For model runs that are coupled to the STSM and have dynamic state classes, grazing preference and NPP are also updated.

##4. References

Boone, R. B., & Galvin, K. A. (2014). Simulation as an approach to social-ecological integration, with an emphasis on agent-based modeling. In M.J. Manfredo et al. (Eds.), Understanding Society and Natural Resources (pp. 179-202). Dordrecht: Springer.
Department of the Interior (2014). DOI Bison Report: Looking Forward. Natural Resource Report NPS/NRSS/BRMD/NRR-2014/821. National Park Service, Fort Collins, Colorado, USA.
Feist, M. (2000). Basic nutrition of bison. Agriculture Knowledge Centre, Saskatchewan Agriculture.

Grimm, V., Berger, U., DeAngelis, D. L., Polhill, J. G., Giske, J., & Railsback, S. F. (2010). The ODD protocol: A review and first update. Ecological Modelling, 221(23), 2760-2768.

Licht, D. S. (2016). Bison weights from national parks in the northern Great Plains. Rangelands, 38, 138-144.

Miller, B. W., Symstad, A. J., Frid, L., Fisichelli, N. A., & Schuurman, G. W. (2017). Co-producing simulation models to inform resource management: A case study from southwest South Dakota. Ecosphere, 8(12).
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Effect--stocking-density on forage production" repetitions="30" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="120"/>
    <metric>mean [biomass] of patches</metric>
    <steppedValueSet variable="bison-num" first="0" step="400" last="2000"/>
    <enumeratedValueSet variable="Random-weather-number">
      <value value="22"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Effect of Drought on forage production" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="100"/>
    <metric>mean [biomass] of patches</metric>
    <enumeratedValueSet variable="bison-num">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Random-weather-number">
      <value value="22"/>
      <value value="23"/>
    </enumeratedValueSet>
    <steppedValueSet variable="inyear" first="1985" step="1" last="1991"/>
  </experiment>
  <experiment name="scenario analysis--observed vs drought" repetitions="10" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="3650"/>
    <metric>mean [biomass] of patches with [lc &gt; 0]</metric>
    <metric>count bison</metric>
    <metric>dead</metric>
    <metric>inyear</metric>
    <metric>annual-rainfall</metric>
    <metric>ticks</metric>
    <enumeratedValueSet variable="Random-weather-number">
      <value value="0"/>
      <value value="21"/>
      <value value="24"/>
      <value value="25"/>
    </enumeratedValueSet>
    <steppedValueSet variable="bison-num" first="400" step="400" last="2000"/>
  </experiment>
  <experiment name="scenario_experiment_2000-2014_5.11.15" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <timeLimit steps="5475"/>
    <metric>mean [biomass] of patches with [lc &gt; 0]</metric>
    <metric>count bison</metric>
    <metric>mean [mass] of bison</metric>
    <metric>dead / bison-cnt</metric>
    <metric>inyear</metric>
    <metric>annual-rainfall</metric>
    <metric>growing-season</metric>
    <metric>ticks</metric>
    <enumeratedValueSet variable="Random-weather-number">
      <value value="26"/>
      <value value="27"/>
    </enumeratedValueSet>
    <steppedValueSet variable="bison-num" first="400" step="400" last="2000"/>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
