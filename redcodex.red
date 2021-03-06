Red [
	Title: "Red Code Explorer"
	Description: "Study the code base of the glorious language with comfort!"
	Author: @hiiamboris
	License: "GPLv3 - https://www.gnu.org/licenses/gpl-3.0.en.html"
	Version: 0.1.2
	Needs: View
]

; TODO: rewire this using Elastic UI
; TODO: an option to download Red sources automatically ?
; TODO: highlight words in the text by a click; up/down navigation from a highlighted word using pointing devices
; TODO: advanced query: list all words by a subword ?
; TODO: save/load subjects/paths, window size, red root ?
; TODO: destroy/hide columns to clean up the window
; TODO: wish about lazier reactivity, like this one
; TODO: relax face!
; TODO: more coloring when RTD is stable: []() */+-//(all operators) {strings} set-words: types! logics? as/declare/...(keywords)
;       even better - mark words that are local to the function, those defined in the context, and those unknown (global?)
; TODO: switch to D2D rendering, as GDI+ font support is pathetic
; TODO: autoupdate files that were changed; locate the closest match when target line does not contain it

try [#include %glob.red]

main: does [
	load-glob-module
	locate-red-root
	patch-w8+bugs
	config: object config
	; BUG: this crashes if invoked after the build-index
	clock [build-index]
	config/fonts/cell-size: determine-cell-size config/fonts/fixed
	relax-reactivity
	make-view
	quit
]

config: [
	skin: 'native
	skin: 'vaporwave

	include-tests?: no
	masks: ["*.reds" "*.red"]

	skins: object [
		vaporwave: object [
			colors: object [
				foreground: magenta - (red * 0.2)
				background: black + (purple * 0.15)
				hilite-background: hilite: gold  ;cyan
				selection: comment: cyan ;gold
				; hilite: (yellow * 0.4) + (magenta * 0.1)
			]
			fonts: object [
				; fixed: make font! [name: "Courier" size: 12]
				; fixed: make font! [name: "Fixedsys" size: 12]
				fixed: make font! [name: "ZX Spectrum-7" size: 18]
				text: input: fixed
				cell-size: [1.0 1.0]
				hilite-char: #"_"
				hilite-offset: 0x3
			]
		]
		native: object [
			colors: object [
				foreground: system/view/metrics/colors/text
				background: system/view/metrics/colors/window
				hilite: selection: comment: color-mix/pure background foreground 2.0
				hilite-background: color-mix background foreground -0.3
			]
			fonts: object [
				fixed: make font! [name: system/view/fonts/fixed size: 10]
				text: input: fixed
				cell-size: [1.0 1.0]
				hilite-char: #"???"
				hilite-offset: 0x0
			]
		]
	]
	colors: skins/:skin/colors
	fonts:  skins/:skin/fonts
	run-cmd: [
		call rejoin
		[ {edit "} to-local-file clean-path filename {"} ]
	]
]

rules: context [
	; NOTE: `-` and `+` are normal 1st word chars
	; so +123 and -123 are as perfect words as x123... is there an easy fix?
	; + there's a special meaning to `a<b>` lexical patterns, not accounted for
	-whitespace-: charset "^(20)^-^M^/^(00A0)"
	-not-word-char-: union -whitespace- charset {/\^^,[](){}"#%$@:;}
	-word-prefix-:   union -not-word-char- charset "'" 	; index ['word] as [word]
	-not-word-1st-:  union -word-prefix- charset "0123465798"
	-word-1st-:  negate -not-word-1st-
	-word-char-: negate -not-word-char-

	-word-: [-word-1st- any -word-char-]
	-set-word-: [-word- #":"]
	-any-word-: [-word- opt #":"]

	-pos-: -wbgn-: -wend-: -wstr-: none  -wact-: []
	; -wact-: [probe -wstr-]
	-whole-word-: [-wbgn-: copy -wstr- -any-word- -wend-: (do -wact-)]
	-line-: [opt -whole-word- any [thru [-word-prefix- -whole-word-]] to end]
]


color-mix: function [c0 [tuple!] c1 [tuple!] mix [number!] /pure] [
	c: copy [0.0 0.0 0.0]
	repeat i 3 [c/:i: (c1/:i * max 0.0 mix) + (c0/:i * max 0.0 1.0 - mix)]
	hi: max max c/1 c/2 c/3
	lo: min min c/1 c/2 c/3
	if lo = hi [lo: lo - 1]
	if 255 < hi [
		repeat i 3 [
			c/:i: to integer! c/:i - (hi - 255.0 * (c/:i - lo) / (hi - lo))
		]
		hi: 255
	]
	if 0 > lo [
		repeat i 3 [
			c/:i: to integer! c/:i - (lo * (hi - c/:i) / (hi - lo))
		]
	]
	repeat i 3 [c/:i: max 0 min 255 to-integer c/:i]
	; input
	c: to-tuple c
	unless pure [
		~: make op! function [a [tuple!] b [tuple!]] [
			d: 0  repeat i 3 [d: max d absolute a/:i - b/:i]
			d < 25
		]
		;-- edge cases require a plan B
		case [
			all [mix < 0  c0 ~ c] [c: color-mix c0 c1 0 - mix]
			all [mix > 1  c1 ~ c] [c: color-mix c0 c1 2 - mix]
		]
	]
	c
]

copy-font: func [f [object!]] [ make f [parent: state: none] ]

clone: func [c [char!] n [integer!]] [append/dup copy "" c n]

++: make op! func [s [string! block!] o [integer!]] [skip s o]

detab: function [x [block! string!]] [
	either block? x [
		forall x [detab x/1]
	][
		tab-size: 4
		ws: "^(20)^(20)^(20)^(20)"
		while [x: find x tab] [
			change/part x (skip ws (index? x) - 1 % 4) 1
		]
	]
	x
]


; NOTE: RTD/GDI typesetting is different, result is only approximate
determine-cell-size: function [font [object!]] [
	if empty? t: "" [
		append/dup t (append clone #"x" 101 lf) 100
		take/last t
	]
	size?: function [t] [
		rt: rtd-layout reduce [t]
		rt/font: copy-font font
		rt/size: 0x0
		size-text rt
	]
	unless equal? size? "I||I" size? "WXWQ" [
		print ["Warning: the chosen font" font/name "is not monospaced and will work incorrectly!"]
	]
	sz: size? t
	reduce [1e-2 * sz/x  1e-2 * sz/y]
]

index: #()
;-- format:
; key = set-word or word (string!)
; value = #(%pathname = [line-number line-number ...] ...)

build-index: function [] [
	unless exists? %red.r [print ["expected root directory of Red:" to-local-file what-dir] input quit]
	print "Building word index..."
	fs: glob/only/files config/masks
	foreach f fs pick [
		[index-file f]
		[unless find f "tests/" [index-file f]]
	] config/include-tests?
]


index-file: function [file [file!]] bind [
	print ["indexing" to-local-file file]
	ls: read/lines file
	set '-wact- [
		key: -wstr-
		unless map: select index key [put index key map: copy #()]
		unless idxs: select map file [put map file idxs: copy []]
		append idxs index? ls
	]
	forall ls [parse ls/1 -line-]
] rules


list-lines: function [w [string!]] [
	collect [
		if m: index/:w [
			foreach f keys-of m [
				foreach l m/:f [
					keep reduce [f l]
	]	]	]	]
]


clock: func [code /local t1 t2] [
	t1: now/precise/time
	do code
	t2: now/precise/time
	print [(t2 - t1) mold/flat code]
]

set-focus*: :set-focus
set-focus: function [f [object!]] [
	set-focus* f
	all [
		f/actors
		not find [area field] f/type
		in f/actors 'on-focus
		f/actors/on-focus f none  	; fix for not working on-focus event
	]
]

place-after: function [f1 [object!] f2 [object!]] [
	pos: find/tail f1/parent/pane f1
	react/link function [f1 f2] [
		ofs: f1/size * 1x0 + f1/offset + 12x0
		case [
			none? f2/offset [f2/offset: ofs]
			ofs/x <> f2/offset/x [f2/offset/x: ofs/x]
		]
	] [f1 f2]
	; print ["placed" f2/extra/id "after" f1/extra/id]
	unless same? pos/1 f2 [change pos f2]
]

; focal-face: function [w [object!]] [
; 	while [face? w/selected] [w: w/selected]
; 	w
; ]

context [	;@@ TODO: these are buggy as they do not consider non-client area size
    translate: func [xy fa op] [
        until [
            xy: xy op fa/offset
            fa: fa/parent
            fa/type = 'screen
        ]
        xy
    ]

    set 'face-to-screen func [
        "Translate a point in face space into screen space"
        xy [pair!] face [object!]
    ][
        translate xy face :+
    ]

    set 'screen-to-face func [
        "Translate a point in screen space into face space"
        xy [pair!] face [object!]
    ][
        translate xy face :-
    ]

    set 'face-to-face func [
        "Translate a point from face1 space into face2 space"
        xy [pair!] face1 [object!] face2 [object!]
    ][
        screen-to-face face-to-screen xy face1 face2
    ]
]

last-used-id: 0

system/view/VID/styles/search-column: [
	template: [
		type: 'panel
		size: 400x600
		extra: make deep-reactor! [
			class: 'search-column
			id: 0
			type: 'files
			path: none
		]
		actors: [
			on-created: function [face] [
				set 'last-used-id face/extra/id: last-used-id + 1
				fl: make-face 'area  fl/size/y: 20
				tc: make-face 'text-column
				fl/font: copy config/fonts/input
				fl/offset: 0x0
				tc/offset: fl/size * 0x1

				; tie sizes
				react/link function [fa tc fl pa] [
					flx: tc/offset/x + fax: tc/size/x
					if fax <> fa/size/x [fa/size/x: fax]
					if flx <> fl/size/x [fl/size/x: flx]
					tcy: (fay: pa/size/y) - tc/offset/y
					if fay <> fa/size/y [fa/size/y: fay]
					if tcy <> tc/size/y [tc/size/y: tcy]
				] [face tc fl face/parent]

				; tie type => tc/content-type
				react/link func [faex tcex] [
					tcex/content-type: faex/type
				] [face/extra tc/extra]
				
				; tie path => tc/file
				react/link func [faex tcex] [
					; print [faex/path tcex/file faex/type]
					if all [faex/type = 'text  faex/path] [
						tcex/file: copy faex/path
					]
				] [face/extra tc/extra]
				
				; tie fl/text => tc/subject
				react/link func [fl tcex] [
					if fl/text [tcex/subject: copy fl/text]
				] [fl tc/extra]

				face/pane: reduce [fl tc]

				unless buggy-w8+? [set-focus fl]
			]
		]
	]
]


; text-column is meant to display 2 things:
; 1) file text, with some word highlighted, and panned to it - when given a file & word
; 2) file+line number list, with some line selected and panned to it - given a word only
text-column: context [

	init: function [f [object!]] [
		
		;-- tie data => text facets & text => width
		react/link function [fa ex] [
			fa/text: form-data fa/data ex/content-type
			x': to-integer first cells-to-size 1x1 * compute-width fa/text ex/content-type
			if x' <> fa/size/x [fa/size/x: x']
		] [f f/extra]

		;-- tie file => text/data
		react/link function [fa ex] [
			if ex/content-type = 'text [
				fa/data: either ex/file [ detab read/lines ex/file ][ [] ]
			]
		] [f f/extra]

		;-- tie subject => file/data
		react/link function [fa ex] [
			if ex/content-type = 'files [
				fa/data: either ex/subject [list-lines ex/subject][ [] ]
			]
		] [f f/extra]

		;-- for files: automatically select something correct
		react/link function [fa ex] [
			if ex/content-type = 'files [
				sel: min length? fa/text max 1 any [fa/selected 1] 	; = 0 if no files
				if 0 < sel [fa/selected: sel]
			]
		] [f f/extra]

		;-- tie selected (integer) line => hilite
		react/link function [fa ex] [
			if all [fa/selected fa/text 0 < length? fa/text] [
				ex/hilite: hilite-for-line fa/text fa/selected
			]
		] [f f/extra]

		;-- autopan: hilite => offset (can't do for text or it will jump on mouse over)
		react/link function [fa ex] [
			if all [
				ex/content-type = 'files
				ex/hilite
			][
				ori: pan-to-hilite ex/origin fa/size fa/text ex/hilite
				if ori <> ex/origin [
					ex/origin: ori
					render-text fa ex 	;-- react BUG: this shouldn't be required
				]
			]
		] [f f/extra]

		;-- for text: autopan to the initial highlight only
		if all [
			f/extra/content-type = 'text
			f/extra/hilite
		][
			f/extra/origin: pan-to-hilite f/extra/origin f/size f/text f/extra/hilite
		]

		react/link/later :render-text [f f/extra]
	]

	form-data: function [data [block! none!] type [word!]] [
		collect [if data [
			either type = 'text [
				lines: data
				forall lines [
					keep form reduce [pad/left index? lines 4  lines/1]
				]
			][
				prev: none
				foreach [file line] data [
					keep line: rejoin [form to-local-file file "/" line]
					; unless line = prev [keep line]   can't skip yet or will be unable to find index in data
					prev: line
				]
			]
		]]
	]

	offset-to-cells: function [ofs [pair!] /from origin [pair!]] [
		if origin [ofs: ofs + origin]
		cs: config/fonts/cell-size
		lh: round/to cs/2 1
		as-pair  ofs/x / cs/1  ofs/y / lh
	]

	cells-to-size: function [cells [pair!]] [
		cs: config/fonts/cell-size
		lh: round/to cs/2 1
		as-pair  to-integer cells/x * cs/1  cells/y * lh
	]

	get-line-number: func [f [object!] o [pair!] /abs] [
		unless abs [o: o + f/extra/origin]
		1 + second offset-to-cells o * 0x1
	]

	hilite-for-line: func [text [block!] n [integer!] /local ln] [
		ln: pick text n
		reduce [n ln tail ln]
	]

	hilite-for-word: function [f [object!] n [integer!] w [string!]] bind [
		hl: none
		if f/extra/content-type = 'text [
			set '-wact- [
				if all [none? hl  -wstr- = w] [
					hl: reduce [n -wbgn- -wend-]
				]
			]
			parse f/text/:n -line-
		]
		hl
	] rules

	get-content-at: function [face [object!] ofs [pair!]] bind [
		cells: offset-to-cells/from ofs face/extra/origin
		ln: pick face/text n: cells/2 + 1
		r: none
		if ln [
			either 'text = face/extra/content-type [
				ix: at ln cells/1 + 1
				set '-wact- [
					if all [
						0 <= offset? -wbgn- ix
						0 <  offset? ix -wend-
					][
						r: reduce [n -wbgn- -wend-]
					]
				]
				parse ln -line-
			][
				r: hilite-for-line face/text n
			]
		]
		r
	] rules

	compute-width: function [lines [block!] type [word!]] [
		either type = 'text [
			; smarter strategy, allows some lines to be longer than the width
			fit: 0 dont: 0 width: 70
			foreach l lines [
				either width >= length? l [fit: fit + 1][dont: dont + 1]
				if all [fit > 20  1.0 * dont / fit > 5%] [width: width + 5  dont: 0]
			]
			width: min 120 width
		][
			; blunt strategy, fit everything
			width: 20
			foreach l lines [width: max width length? l]
			width: min 60 width
		]
		width
	]

	choose: function [face [object!] what [block!] /local file line] [
		sc: face/parent
		text?: face/extra/content-type = 'text
		unless next-sc: second find sc/parent/pane sc [
			next-sc: make-face 'search-column
			next-sc/extra/type: pick [files text] text? 	; reverse the type
			place-after sc next-sc
		]
		next-tc: last next-sc/pane
		set-focus next-tc
		
		either text? [
			w: copy/part what/2 what/3
			either #":" = last w [take/last w] [append w #":"]
			next-sc/pane/1/text: w
		][
			set [file line] skip face/data what/1 - 1 * 2
			next-sc/extra/path: copy file
			next-sc/pane/1/text: sub: copy sc/pane/1/text 	;-- BUG: somehow `area` gets an extra newline...
			next-tc/extra/hilite: hl: hilite-for-word next-tc line sub
			next-tc/extra/origin: pan-to-hilite next-tc/extra/origin next-tc/size next-tc/text hl
		]
		pan-to-show-face next-sc
	]

	scroll: function [face [object!] 'dir [word!] amnt [number!]] [
		h: second cells-to-size 0x1 * length? face/text
		ex: face/extra
		either find [up down] dir [
			if percent? amnt [amnt: face/size/y * amnt]
			amnt: to integer! amnt
			newy: amnt * (pick [1 -1] dir = 'down) + ex/origin/y
			newy: max 0 min h newy
		][
			switch dir [
				bgn [newy: 0]
				end [newy: h]
			]
		]
		newy: second normalize-origin  0x1 * newy  0x1 * h  face/size
		also newy - ex/origin/y
			ex/origin/y: newy
	]

	select-line: function [face [object!] 'line [word! integer! percent!]] [
		switch type?/word line [
			word! [
				line: (any [face/selected 0]) + second find [back -1 next 1] line
			]
			percent! [
				fit: face/size/y / config/fonts/cell-size/2
				line: to-integer fit * line + any [face/selected 1]
			]
		]
		line: max 1 min to integer! (length? face/data) / 2 line
		face/selected: line
	]

	select-subject: function [face [object!] 'selector [word!]] bind [
		ex: face/extra
		unless ex/subject [exit]
		selector: get selector
		either ex/hilite [
			lines: at face/text ex/hilite/1
			lines: selector lines
		][
			y: either same? :back :selector [0][face/size/y]
			lines: -1 + get-line-number face y
		]
		found?: none
		set '-wact- [if -wstr- = ex/subject [found?: index? lines]]
		until [
			ln: lines/1
			parse ln -line-
			if found? [
				ex/hilite: hilite-for-word face found? ex/subject
				ex/origin: pan-to-hilite ex/origin face/size face/text ex/hilite
				break
			]
			lines: selector lines
			any [head? lines  tail? lines]
		]
	] rules

	focus-adjacent-column: function [face [object!] selector [any-function!]] [
		pos: selector find face/parent/parent/pane face/parent
		if all [pos/1  object? pos/1/extra  pos/1/extra/class = 'search-column] [
			set-focus f': pos/1/pane/2
			; pan-to-show-face f'
		]
	]

	normalize-origin: function [origin [pair!] canvas [pair!] viewport [pair!]] [
		max 0x0 min origin canvas - viewport + 40x40
	]

	pan-to-hilite: function [origin [pair!] size [pair!] text [block!] hl [block!]] [
		pos1: cells-to-size -1x-1 + as-pair index? hl/2 hl/1
		pos2: cells-to-size -1x0  + as-pair index? hl/3 hl/1
		pos1: pos1 - origin
		pos2: pos2 - origin
		r: origin
		if pos2/y > size/y 	[ r/y: r/y + pos2/y - ((to integer! size/y / 4) * 3) ]
		if pos1/y < 0			[ r/y: r/y + pos1/y -  (to integer! size/y / 4) ]
		if pos2/x > size/x 	[ r/x: r/x + pos2/x - size/x ]
		if pos1/x < 0			[ r/x: r/x + pos1/x ]
		canvas: cells-to-size as-pair 120 length? text
		normalize-origin r canvas size
	]

	; pan-to-line: function [f [object!] n [integer!]] [
	; 	ori: (cells-to-size 0x1 * to-integer n - 1) - (f/size / 4 * 0x1)
	; 	scroll f down (ori/y - f/extra/origin/y)
	; ]

	pan-to-show-face: function [
		"pan parent to show the face fully and some of it's surroundings"
		fa [object!] "text-column or search-column"
		; cv [object!] "parent canvas containing `fa`"
		; wi [object!] "clipping window or panel containing `cv`"
	][
		unless fa/extra/class = 'search-column [fa: fa/parent]
		cv: fa/parent  wi: cv/parent
		fa2: fa/size + fa1: fa/offset    ; fa box inside cv
		cvo: cv/offset
		fa1: fa1 + cvo  fa2: fa2 + cvo   ; fa box inside wi
		wis: wi/size
		mrg: 50x0 		; margins to display around
		unless all [
			within? fa1 mrg wis - mrg
			within? fa2 mrg wis - mrg
		][ ; some parts are obscured...
			if within? fa/size 0x0 wis - (mrg * 2) [ 	; possible to fit in?
				fa1: max mrg fa1  fa2: fa1 + fa/size
				fa2: min fa2 wis  fa1: fa2 - fa/size
				cvo: fa1 - fa/offset
				cv/offset: 0x0 - normalize-origin 0x0 - cvo cv/size wi/size
			]
		]
	]

	make-excerpt: function [text [string!] hd [integer! string!] tl [integer! string!]] [
		unless integer? hd [hd: offset? text hd]
		unless integer? tl [tl: offset? text tl]
		also r: clone sp (length? text) + hd - tl
		insert/part  r ++ hd  text ++ hd  tl - hd
	]

	leave-only: function [text [string! none!] sub [string! none!]] [
		if any [empty? sub empty? text] [return none]
		r: copy ""  found?: no
		parse text [collect into r [any [
			s: [
				thru [e: sub]
				keep (clone sp offset? s e)
				keep (copy/part e length? sub)
				(found?: yes)
			|	to end
				keep (clone sp offset? s e)
			]
		]]]
		either found? [r][none]
	]

	make-boxes: function [text [string! none!]] [
		replace/all  copy text  charset [not 20h]  config/fonts/hilite-char
	]

	render-text: function [face [object!] extra [object!] /local ctxt csel cbox chlt ccom] [
		; print ["REDRAW id=" extra/id extra/hilite]
		lines: face/text  ori: extra/origin  sz: face/size  cs: config/fonts/cell-size
		hlofs: config/fonts/hilite-offset
		if empty? lines [face/draw: [] exit]
		set [ctxt csel cbox chlt ccom] reduce bind
			 [foreground selection hilite-background hilite comment] config/colors
		
		text?: 'text = extra/content-type

		face/draw: collect [
			;-- prefix
			keep compose [pen (ctxt) font (face/font)]

			;-- boxes & lines & comments
			cells: 0x1 * offset-to-cells/from 0x0 ori
			sub: extra/subject
			lines': lines ++ cells/y
			forall lines' [
				pos: (cells-to-size cells) - ori
				if sz/y <= pos/y [break]
				ln: lines'/1
				if all [text?  subs: leave-only ln sub][
					keep compose [pen (cbox) text (pos + hlofs) (make-boxes subs) pen (ctxt)]
				]
				keep compose [text (pos) (ln)]
				if all [text?  subs][
					keep compose [pen (chlt) text (pos) (subs) pen (ctxt)]
				]
				if com: find ln #";" [
					exc: make-excerpt ln com length? ln
					keep compose [pen (ccom) text (pos) (exc) pen (ctxt)]
				]
				cells/y: cells/y + 1
			]

			;-- selection
			if all [
				hl: extra/hilite
				pos: (cells-to-size hl/1 - 1 * 0x1) - ori
				pos/y < sz/y
			][
				if ln: pick lines hl/1 [
					exc: make-excerpt ln hl/2 hl/3
					keep compose [pen (csel) text (pos + 2x0) (exc)]
				]
			]

		]
	]

	; record a path of past origin points
	record-point: function [ex [object!] limit [time!]] [
		repend ps: ex/points [ex/origin t: now/time/precise]
		; clean up points before a given T - limit
		while [all [
			not empty? ps
			limit < to time! t - ps/2 // 24:0:0
		]] [ps: ps ++ 2]
		ps: remove/part head ps ps
	]

	calc-velocity: function [ps [block!]] [
		r: 0.0
		if 4 <= length? ps [
			dofs: (pick tail ps -2) - ps/1
			dtim: (last ps) - to-time ps/2 // 24:0:0
			if dtim > 0:0:0 [r: dofs/y * 1.0 / dtim/second]
		]
		r
	]

	; since-last-point: func [ex [object!]] [

	; ]
]


scroller: context [

	autosize: func [f p] [
		either f/offset/y > 1
			[ if p/size/x <> f/size/x [f/size/x: p/size/x] ]
			[ if p/size/y <> f/size/y [f/size/y: p/size/y] ]
	]

	set-target: function [extra [object! none!] target [object! none!]] [
		; print ["set target of" either extra [class-of extra][none] "to" either target [class-of target][none]]
		if all [extra  not same? t2: target t1: extra/auto-target] [
			all [t1  react/unlink :on-move [extra t1]]
			all [t2  react/link   :on-move [extra t2]]
		]
		target
	]

	adjust-target: function [extra [object!] used [block!]] [
		unless t: extra/target [exit]
		i: pick [1 2] 'we = extra/shape
		ofs: negate to-integer round used/1 * t/size/:i
		if ofs <> t/offset/:i [t/offset/:i: ofs]
	]

	on-move: function [extra [object!] target [object!]] [
		unless target/parent [exit]
		i: pick [1 2] 'we = extra/shape
		content: target/size/:i
		offset: target/offset/:i
		frame: target/parent/size/:i
		used: reduce [
			max 0.0 0.0 - offset / content
			min 1.0 0.0 - offset + frame / content
		]
		extra/used: used
	]

	render-geom: function [face [object!] extra [object!]] [
		sz: face/size
		sh: either sz/y > sz/x [sz/x: also sz/y sz/y: sz/x  'ns]['we]
		unless sh = extra/shape [extra/shape: sh]
		x1: sz/x * max 0 min 1 any [extra/used/1 0]
		x2: sz/x * max 0 min 1 any [extra/used/2 1]
		vis: all [x2 > x1  x2 - x1 < sz/x]
		face/visible?: vis
		face/draw: collect [
			if vis [
				if sz/y > sz/x [keep [matrix [0 1 1 0 0 0]]]
				keep compose [
					pen off fill-pen (extra/runner-color)
					box (as-pair x1 0) (as-pair x2 - 1 sz/y)
				]
			]
		]
	]
]


system/view/VID/styles/scroller: bind [
	default-actor: on-down
	template: [
		type: 'base
		size: 200x20
		color: config/colors/background
		flags: [all-over]

		extra: make deep-reactor! [
			class: 'scroller
			id: 0
			used: [0 1]
			target: none
			shape: 'we 		; ns or we
			auto-target: is [set-target extra target]
			runner-color: config/colors/hilite
		]

		actors: [
			on-created: func [f] [
				react/link :render-geom [f f/extra]
				react/link :autosize [f f/parent]
			]

			on-over: on-down: function [f e] [
				unless any [e/type = 'down  e/down?] [exit]
				u2: any [f/extra/used/2 1]
				u1: any [f/extra/used/1 0]
				du: u2 - u1
				u1: 1.0 * e/offset/x / f/size/x - (du / 2)
				u2: 1.0 * e/offset/x / f/size/x + (du / 2)
				if u2 > 1 [u1: u1 + 1 - u2  u2: 1]
				if u1 < 0 [u2: u2 - u1  u1: 0]
				if u2 > 1 [u2: 1]
				adjust-target f/extra reduce [u1 u2]
			]
		]
	]
] scroller

system/view/VID/styles/text-column: bind [
	default-actor: on-key
	template: [
		type: 'base
		size: 400x600
		color: config/colors/background
		font: copy config/fonts/text
		rate: 67
		flags: [all-over]
		extra: make deep-reactor! [
			class: 'text-column
			id: 0
			content-type: 'text
			file: none
			subject: none
			origin: 0x0
			drag-origin: 0x0
			dragging?: no
			moved?: no
			velocity: 0.0
			last-time: now/time/precise
			hilite: none
			points: reduce [0x0 now/time/precise]
		]

		actors: [
			on-created: function [fa] [
				set 'last-used-id fa/extra/id: last-used-id + 1
				init fa
			]

			on-focus: func [fa ev] [pan-to-show-face fa]
			on-alt-down: function [fa ev] [
				if sel: get-content-at fa ev/offset [choose fa sel]
			]

			on-time: function [fa ev] [
				ex: fa/extra
				t: now/time/precise
				either ex/dragging? [
					; save 
					record-point ex 0:0:0.1
					ex/velocity: calc-velocity ex/points
				][
					if 0 <> ex/velocity [ 	; panning?
						dt: t - to-time ex/last-time // 24:0:0
						dy: round/to ex/velocity * dt/second 1
						ex/moved?: yes
						if 0 = scroll fa down dy [ 	; stop if hit top/bottom
							ex/velocity: 0.0
						]
					]
				]
				ex/last-time: t
			]

			on-dbl-click: function [fa ev] [
				ex: fa/extra
				if all [ex/content-type = 'files ex/hilite] [
					n: get-line-number fa ev/offset
					if filename: pick fa/data n * 2 - 1 [
						do bind config/run-cmd 'filename
					]
				]
			]

			on-down: function [fa ev] [
				set-focus fa
				ex: fa/extra
				ex/velocity: 0.0
				ex/moved?: no
				unless ev/ctrl? [
					ex/drag-origin: ex/origin + ev/offset
					ex/dragging?: yes
				]
			]

			on-up: function [fa ev] [
				ex: fa/extra
				clear ex/points
				ex/dragging?: no
				if all [ev/ctrl? ex/content-type = 'text] [
					n: get-line-number fa ev/offset
					base: https://github.com/red/red/blob/master/
					browse rejoin [base ex/file "#L" n]
				]
				unless any [ev/ctrl?  ex/moved?  0 <> ex/velocity] [
					fa/actors/on-alt-down fa ev
				]
			]

			on-over: function [fa ev] [
				ex: fa/extra
				either ev/down? [	; pan the view
					ori: ex/drag-origin - ev/offset
					if ori/x < 0 [ori/x: 0]
					ex/moved?: ori <> ex/origin
					canvas: cells-to-size as-pair ex/origin/x + ev/offset/x length? fa/text
					ori: normalize-origin ori canvas fa/size
					ex/origin: ori
					; sample the path more often:
					fa/actors/on-time fa ev
				][	; hilite the word under the pointer
					if all [not ev/away?  hl: get-content-at fa ev/offset] [
						ex/hilite: hl
					]
				]
			]

			on-wheel': func [fa ev] [
				scroll fa  (pick [up down] ev/picked > 0)  20%
			]

			on-key: function [f e] [
				ex: f/extra
				switch e/key [
					left  [focus-adjacent-column f :back]
					right [focus-adjacent-column f :next]
				]
				either ex/content-type = 'text [
					switch e/key [
						home  [scroll f bgn 0]
						end   [scroll f end 0]
						down  [scroll f down 20%]
						up    [scroll f up   20%]
						page-down [scroll f down 80%]
						page-up   [scroll f up   80%]
						#"+"	[select-subject f next]
						#"-"	[select-subject f back]
					]
				][
					switch e/key [
						#"^M" [if ex/hilite [choose f ex/hilite]]
						home  [select-line f 1]
						end   [select-line f (length? f/text)]
						down  [select-line f next]
						up    [select-line f back]
						page-down [select-line f +80%]
						page-up   [select-line f -80%]
					]
				]
			]
		]
	]
] text-column


; makes reactors lazy - only reacting when the value really changes
relax-reactivity: function [] [

	set 'reactor! make reactor! [
		on-change**: :on-change*
		on-change**: function [word old [any-type!] new [any-type!]] body-of :on-change*
		on-change*: function spec-of :on-change** [
			unless strict-equal? :old :new [on-change** word :old :new]
		]
	]

	set 'deep-reactor! make reactor! [
		on-deep-change*: function [owner word target action new index part][
			; print ["ON-DEEP-CHANGE!" :owner :word :target :action :new :index :part]
			system/reactivity/check/only owner word
		]
	]

]


load-glob-module: has [e u1 u2] [
	unless value? 'glob [
		print "No GLOB module found, using the remote location..."
		u1: https://gitlab.com/hiiamboris/red-junk/raw/master/glob/glob.red
		u2: https://gist.githubusercontent.com/hiiamboris/605a4ab6831a247ac987789f4d578ef1/raw/a37dad12fb0f01307e8482e8e633b2bc6f5da403/glob.red
		case [
			not error? e: try [do u1]
			not error? e: try [do u2]
			true [
				browse u1
				view compose [area 400x250 wrap (form reduce [
					"There was an error downloading the GLOB module:^/" mold e
					"^/Please download it manually from^/" u1 "and restart"
				])]
				quit
			]
		]
	]
]

locate-red-root: function [] [
	there?: has [f] [
		4 <= sum collect [
			foreach f [%red.r %environment/ %modules/ %runtime/ %system/ %libRed/] [
				if exists? f [keep 1]
			]
		]
	]
	unless there? [
		print "Not in the root of Red source, relocating..."
		write-clipboard as string! u: https://github.com/red/red/
		msg: form reduce [
			"This tool should have been started from the Red sources directory."
			"Please get these from" u "and specify the location"
		]
		until [
			unless d: request-dir/keep/dir/title what-dir msg [quit]
			change-dir d
			there?
		]
	]
]


patch-w8+bugs: has [o] [
	o: os-info
	buggy-w8+?: not find o/name "Windows 7"
]


make-view: does [
	; config/fonts/cell-size: determine-cell-size config/fonts/fixed

	insert-event-func function [f e] [
		; unless find [drawing time] e/type [probe e/type]

		; send wheel events to a face under the pointer
		if e/type = 'wheel [
			; feed the event to a child face
			w: e/window
			focal: e/face
			abs-ofs: face-to-face e/offset focal w
			if within? abs-ofs 0x0 w/size [		; has to be within window borders, ignore otherwise
				child: none
				foreach-face w [
					if all [
						none? child
						face/type = 'base
						true = try [face/extra/class = 'text-column]
					][
						if within? face-to-face abs-ofs w face 0x0 face/size [child: face]
					]
				]
				all [
					on-wheel: attempt [:child/actors/on-wheel']
				 	on-wheel child e
				]
			]
			'stop
		]

		if e/type = 'key-down [
			case [

				e/key = tab [
					w: e/window
					f-: none
					foreach-face w [
						; if f- [continue] 	; crashes
						if any [
							face/type = 'area
							all [
								face/type = 'base
								true = try [face/extra/class = 'text-column]
							]
						][
							case [
								same? face f [
									if all [e/shift? f-] [set-focus f-]
								]
								same? f- f [
									unless e/shift? [set-focus face]
								]
							]
							f-: face
						]
					]
					return 'stop
				]

				all [e/key = #"^M"  f/type = 'area] [
					tc: second find f/parent/pane f
					either 1 = length? tc/text [text-column/choose tc [1]] [
						set-focus tc
					]
					return 'stop
				]

				e/key = 'F1 [
					view/flags compose [
						area wrap 400x400 font-size 10 (form reduce [
							"~ RedCodeX ~"
							"^/https://gitlab.com/hiiamboris/red-codex^/"
							"^/Controls list^/"
							"^/Mouse:^/"
							"- WHEEL or LEFT-click + HOLD to PAN the view^/"
							"- LEFT-click / RIGHT-click to LOOKUP a word or open a file^/"
							"- DOUBLE LEFT-click on a file to open it with `EDIT` command^/"
							"- CTRL + LEFT-click on a line to open it on GITHUB in your browser^/"
							"^/Keys:^/"
							"- ordered TAB navigation^/"
							"- LEFT/RIGHT to move between ADJACENT columns^/"
							"- UP/DOWN/HOME/END/PAGEUP/PAGEDOWN to navigate in the column^/"
							"- PLUS/MINUS to FIND next/previous subject in the text^/"
							"^/Tips:^/"
							"- add a '*' manually if you're looking for a native source: `prin:` -> `prin*:`"
						])
						return pad 300x0 button focus "KTHX!" [unview]
					][modal]
				]
			]
		]
	]

	view/tight/flags/options compose [
		columns: panel [
			at 0x0 search-column
		] with [
			; auto stretching logic
			extra: is (bind [
				if extra <> last pane [
					react/unlink :fn 'all
					unless empty? pane [react/link :fn [context? 'extra last pane]]
				]
				last pane
			] context [
				fn: function [fa ex] [
					x': ex/size/x + ex/offset/x
					if x' <> fa/size/x [fa/size/x: x']
				]
			])
		]
		return
		scrr: scroller 800x20 with [extra/target: columns]
	] [resize] [
		offset: 0x0
		text: "Red Source Code Explorer"
		actors: object [

			on-created: func [f] [
				; fit scroller to the bottom, stretch columns to fit the window
				react/link function [col scr wnd][
					sy: wnd/size/y - scr/size/y
					if sy <> scr/offset/y [scr/offset/y: sy]
					csy: sy - col/offset/y
					unless scr/visible? [csy: csy + scr/size/y]
					if csy <> col/size/y [col/size/y: csy]
				] [columns scrr scrr/parent]
			]

			on-close: func [f e] [clear-reactions]

			; on-resize: function [f e] [
			; 	; f/size: f/size 	; trick to get react triggered by window size change
			; ]

		]
	]
]

main
