globals [
population-size
  infected-count
  healthy-count
  dead-count
  recovered-count
  rat-infections
  flea-infections
  human-infections
  start-date

]

;ticks represent hours

breed [humans human]
breed [rats rat]
breed [fleas flea]

breed [houses house]

houses-own [
  family-id
  purpose
]

humans-own [
  family-id
  infected?      ; if true, the turtle is infected
  infection-type ; if infected, which strain of the plague
  hours-infected ; counts how many hours the turtle has been infected
  incubation-rate; length of time that turtle is infectious (if infected)
  attached-fleas ;number of fleas they are hosting
  mortality-rate;
  alive?
  immune?
  infected-this-tick? ; flag to prevent multiple infections in the same tick
  infection-completed?
  my-home-location
]

rats-own [
  infected?  ; same as for humans
  attached-fleas
  hours-infected
  incubation-rate
  alive?
  immune?
  infection-type
  mortality-rate;
  infected-this-tick? ; flag to prevent multiple infections in the same tick
  infection-completed?
]

fleas-own [
  infected?
  host ; which turtle the flea is being carried on
  alive?
]

links-own [family-link?]

to setup
  clear-all

  set population-size 700
  set rat-infections 0
  set flea-infections 0
  set human-infections 0
  set start-date [1665 9 5 0]

  ;Create humans
  setup-villagers

  ask links [
    set hidden? true
  ]

  ; Create rats
  create-rats rat-population [
    setxy random-xcor random-ycor
    set infected? false
    set color brown
    set shape "rat"
    set incubation-rate 0
    set hours-infected 0
    set attached-fleas 0
    set alive? true
    set immune? false
    set infected-this-tick? false
    set infection-completed? false ; Initialize infection-completed? flag
  ]

  ; Create fleas
  create-fleas flea-population [
    setxy 0 0 ;Location of package
    set infected? true
    set color red
    set shape "flea"
    set alive? true
    find-closest-rat
    if host = nobody [find-closest-human]
  ]

  create-houses 1 [
    setxy random-xcor random-ycor
    set purpose "church"
    set color yellow
  ]

  update-counts
  reset-ticks
  initialise-plots
end


to setup-villagers

let new-family-id 0
  while [count humans < population-size] [
    set new-family-id new-family-id + 1
    let family-size random 5 + 2
    let family-x random-xcor
    let family-y random-ycor
    create-humans family-size [
      set family-id new-family-id
       setxy (family-x + random-float 2 - 1) (family-y + random-float 2 - 1)

    set infected? false
    set infection-type "NA"
    set incubation-rate 0
    set hours-infected 0
    set attached-fleas 0
    set color green
    set shape "person"
    set alive? true
    set immune? false
    set infected-this-tick? false
    set infection-completed? false
    ]
    create-houses 1 [
      setxy family-x family-y
      set family-id new-family-id
      set shape "house"
      set purpose "home"
  ]

    ask humans with [family-id = new-family-id] [
      create-links-with other humans with [family-id = new-family-id]
      [set family-link? true]
      let my-home one-of houses with [family-id = new-family-id]
      set my-home-location my-home
    ]

  ]
end


to go
  reset-infected-this-tick
  movement-phase
  infection-phase
  update-counts

  tick
  refresh-plots
end

to reset-infected-this-tick
  ask humans [ set infected-this-tick? false ]
  ask rats [ set infected-this-tick? false ]
end

to movement-phase
  ask fleas [if alive? [move-fleas]]
  ask rats [if alive? [move-rats]]
  ask humans [if alive? [move-humans]]
end

to move-humans
  if alive? [
    ; Only move between 6 AM (tick 6) and 10 PM (tick 22) every day
    ifelse ticks mod 24 >= 6 and ticks mod 24 <= 22 [
      ;ifelse ticks mod 7 >= 1 and ticks mod 7 <= 2 [
       ; let my-church one-of houses with [purpose = "church"]
        ;let church-x [xcor] of my-church
        ;let church-y [ycor] of my-church
        ;face patch church-x church-y
        ;move-to patch church-x church-y

        ;if ticks mod 7 = 2 [
         ;let home-x [xcor] of my-home-location
          ;let home-y [ycor] of my-home-location
          ;face patch home-x home-y
          ;move-to patch home-x home-y

      ;]
      ;[


      rt random 360  ; Random turn

      fd 1           ; Move forward by 1 step
    ]

    [
  let home-x [xcor] of my-home-location
  let home-y [ycor] of my-home-location
  face patch home-x home-y
  forward 1  ;

  ]
  ]


end

to move-rats
  if alive? [
    ; Only move between 8:30 PM (tick 20) and 5:30 AM (tick 6) every day
    if ticks mod 24 >= 20 or ticks mod 24 <= 6 [
      rt random 360  ; Random turn
      fd 0.5           ; Move forward by 1 step
    ]
  ]
end

to move-fleas
  ask fleas [
    ifelse host != nobody [
      ifelse [alive?] of host [
        move-to host
      ] [
        detach-from-host
        find-closest-human
        kill-flea
      ]
    ] [
      find-closest-rat
    ]
  ]
end

to infection-phase
  ask humans [
    if infected?[
      human-spread-infection
      set hours-infected hours-infected + 1
      if hours-infected > incubation-rate and not infection-completed?  [
        try-recover-or-die
        set infection-completed? true  ; Mark as completed after infection process
      ]
    ]
  ]

  ask rats [
    if infected? and not infection-completed? [
      set hours-infected hours-infected + 1
      if hours-infected > incubation-rate [
        try-recover-or-die
        set infection-completed? true  ; Mark as completed after infection process
      ]
    ]
  ]

  ask fleas [
    if infected? and host != nobody [
      flea-spread-infection
    ]
  ]
end


to find-closest-rat
  let closest-rat min-one-of rats with [attached-fleas < 2 and alive?][distance myself]
  if closest-rat != nobody [
    set host closest-rat
    ask closest-rat [set attached-fleas attached-fleas + 1]
  ]
end

to find-closest-human
  let closest-human min-one-of humans with [attached-fleas < 2 and alive?] [distance myself]
  if closest-human != nobody [
    set host closest-human
    ask closest-human [set attached-fleas attached-fleas + 1]
  ]
end

to detach-from-host
  if host != nobody [
    ask host [set attached-fleas attached-fleas - 1]
    set host nobody
  ]
end

to release-fleas
  ask fleas with [host = myself] [
    detach-from-host
    find-closest-human
  ]
end

to flea-spread-infection
  ask fleas [
    if ticks >  and infected? and host != nobody and [alive?] of host [
      ask host [
        if not infected-this-tick? and alive? and not immune? and not infected? [  ; Only infect if not already infected this tick
          if random-float 1 < flea-transmission-rate [
            set infected-this-tick? true
            set flea-infections flea-infections + 1
            ifelse breed = humans [
              ifelse random 2 = 1 [bubonic-infect] [pneumonic-infect]

            ; Check if the host is a human

              ask fleas with [host = myself] [kill-flea]
            ]; Kill the flea
              [rat-infect]
            ]
          ]
        ]
      ]
    ]


end

to kill-flea
  set color gray
  set infected? false
  set alive? false
end


to human-spread-infection
  ask other humans-here with [not infected-this-tick? and alive? and not immune? and not infected?] [
    if random-float 1 < human-transmission-rate [
      pneumonic-infect
      set human-infections human-infections + 1
    ]
  ]
  ask link-neighbors with [not infected-this-tick? and alive? and not immune? and not infected?] [
    if random-float 1 < human-transmission-rate [
      pneumonic-infect
      set human-infections human-infections + 1
    ]
  ]

end

to try-recover-or-die
  if infected? and alive? [
    ifelse random-float 1 < mortality-rate [
      set color gray
      set infected? false
      set alive? false
      release-fleas
    ] [
      set infected? false
      set color blue
      set immune? true
    ]
  ]
end

to simulate-weather
  ; Check for specific ticks and apply penalty or bonus accordingly
  if ticks = 0 or ticks = 2040 or ticks = 8520 [
    set flea-transmission-rate (flea-transmission-rate - weather-penalty)
    set human-transmission-rate (human-transmission-rate - weather-penalty)
  ]
  if ticks = 4200 or ticks = 6360 [
    set flea-transmission-rate (flea-transmission-rate + weather-penalty)
    set human-transmission-rate (human-transmission-rate + weather-penalty)
  ]
end


to update-counts
  set infected-count count humans with [infected? and alive?]
  set healthy-count count humans with [color = green]
  set recovered-count count humans with [color = blue]
  set dead-count count humans with [not alive?]
end

to pneumonic-infect
  set infected? true
  set infection-type "pneumonic"
  set color yellow
  set incubation-rate 60
  set mortality-rate 1
end

to rat-infect
  set infected? true
  set color red
  set mortality-rate 0.9
  set incubation-rate 125
end

to bubonic-infect
  set infected? true
  set infection-type "bubonic"
  set color red
  set incubation-rate 240
  set mortality-rate 0.4
end

to-report get-datetime
  let year item 0 start-date

  let month item 1 start-date
  let day item 2 start-date
  let hour (item 3 start-date + ticks) mod 24
  let days-passed floor (item 3 start-date + ticks) / 24

  let new-day floor(day + days-passed)
  let new-month month
  let new-year year

  ; Handle month overflow (assumes 30 days per month for simplicity, or use a more advanced approach below)
  if new-day > 30 [
    set new-month new-month + floor (new-day / 30)
    set new-day new-day mod 30
  ]
  if new-month > 12 [
    set new-year new-year + floor (new-month / 12)
    set new-month new-month mod 12
  ]

  report (word new-year "-" new-month "-" new-day " " hour ":00")
end


to initialise-plots
  set-current-plot "Infection Sources"
  clear-plot
  set-current-plot "Deaths over Time"
  clear-plot
end

to refresh-plots
  set-current-plot "Infection Sources"
  set-current-plot-pen "Flea Infections"
  plot flea-infections
  set-current-plot-pen "Rat Infections"
  plot rat-infections
  set-current-plot-pen "Human Infections"
  plot human-infections
  set-current-plot "Deaths over Time"
  set-current-plot-pen "deaths"
  plot dead-count
end
@#$#@#$#@
GRAPHICS-WINDOW
520
15
1401
897
-1
-1
9.0
1
10
1
1
1
0
1
1
1
-48
48
-48
48
0
0
1
ticks
30.0

BUTTON
350
15
416
48
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

MONITOR
1415
15
1520
60
NIL
infected-count
17
1
11

MONITOR
1415
195
1516
240
NIL
healthy-count
17
1
11

MONITOR
1415
75
1501
120
NIL
dead-count
17
1
11

BUTTON
435
15
498
48
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
1415
135
1532
180
NIL
recovered-count
17
1
11

SLIDER
325
120
497
153
flea-population
flea-population
0
100
50.0
1
1
NIL
HORIZONTAL

PLOT
140
435
495
640
Infection Sources
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Flea Infections" 1.0 0 -2674135 true "" ""
"Rat Infections" 1.0 0 -10402772 true "" ""
"Human Infections" 1.0 0 -14439633 true "" ""

MONITOR
140
370
237
415
NIL
rat-infections
17
1
11

MONITOR
255
370
357
415
NIL
flea-infections
17
1
11

MONITOR
375
370
497
415
NIL
human-infections
17
1
11

INPUTBOX
140
70
280
130
human-transmission-rate
0.015
1
0
Number

INPUTBOX
135
145
282
205
flea-transmission-rate
0.02
1
0
Number

SLIDER
330
75
502
108
rat-population
rat-population
0
100
100.0
1
1
NIL
HORIZONTAL

INPUTBOX
335
190
482
250
weather-penalty
0.01
1
0
Number

PLOT
145
675
345
825
Deaths over Time
Time
Deaths
0.0
11000.0
0.0
700.0
true
false
"" ""
PENS
"deaths" 1.0 0 -16777216 true "" ""

MONITOR
1423
267
1576
312
Current Date and Time
get-datetime
20
1
11

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
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

flea
true
0
Circle -6459832 true false 90 90 120
Line -6459832 false 120 105 75 60
Line -6459832 false 150 105 150 45
Line -6459832 false 180 120 240 75
Line -6459832 false 120 180 75 225
Line -6459832 false 150 195 150 240
Line -16777216 false 15 420 45 465
Line -6459832 false 195 195 240 240
Circle -1 true false 90 120 30
Circle -1 false false 90 150 30
Circle -1 true false 90 150 30
Circle -16777216 true false 150 150 0

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

rat
true
0
Circle -7500403 true true 86 86 127
Circle -7500403 false true 56 56 67
Circle -7500403 false true 176 56 67
Line -16777216 false 135 165 150 180
Line -16777216 false 135 165 165 165
Line -16777216 false 165 165 150 180
Circle -16777216 true false 105 120 30
Circle -16777216 true false 165 120 30
Line -16777216 false 150 180 150 195
Line -16777216 false 150 195 165 195
Line -16777216 false 150 195 135 195

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
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
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
1
@#$#@#$#@
