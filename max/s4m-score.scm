(post "score.scm")

; score.scm a linear score scheduling system for s4m

; put example here yo
; (define s (make-score (hash-table :bbt '(8 4 480) :res 960)
; 1           foo
; 2           'bar
; :+1         '(foo bar)
; :+1         (get-foo)
; 
; ;:1-1-120    'e1-120
; ;:1-1-240    'e1-240
; ;:1-1-360    'e1-360
; ;
; ;2           'e2a 
; ;:.         'c
; ;
; ;9           'b
; ;:+4         'c    ; 8 bars later
; ;:+4         d
; ;:.          foo bar
; )) 

; USAGE
; (s 'play)      - start playback, scheduling according to :res (default 120 ticks)
; (s 'stop)      - stop and rewind to zero
; (s 'pause)     - stop without cueing
; (s 'cue 1)     - cue to bar 1
; (s 'cue 1 120) - cue to bar 1, tick 120

; Data Structure is a hash table of bars and bar-entries, where bar-entries
; is an assoc list of lists, each list starting with a tick and then
; some number of events in order they should be called
; {1:((0 evt-1) (120 evt-2 evt-3) (240 evt-3  ...)} etc
;
; Note that *bar* doesn't need to be the resolution of the hash
; Order in the score declaration only matters for events at the same time

; TODO
; check that bar and tick index are cooperating properly

; FUTURE:
; use a reader macro so we don't need colons or quotes


(define (make-score-seq attr-hash data)
  ; prop-hash is used to set properties from kwargs
  ; args is a set of time events
  (let ((attrs attr-hash)
        (bars-per-section 8)
        (beats-per-bar 4)
        (ticks-per-beat 480)
        (tick-index 0)          ; tick index *within* the current bar  
        (bar-index 0)
        (events-for-bar #f)     ; all events stored at a bar
        (events-left  #f)       ; the events for a bar not yet played
        (tick-res 120)          ; how many ticks per call to the tick function
        (cb-handle #f)
        (playing #f)
        (reader-bar-index 0)    ; bar counter for the reader process
        (events (hash-table)))
    
    ; Constructor to store events passed in as assoc-list of time/event-list
    (define (init data)
      ; if res passed in, use it as tick res
      (if (attrs :res) (set! tick-res (attrs :res)))
      ; if bars-beats-ticks were passed as a constructor arg,
      ; set internal time base values from list passed in, otherwise leave as default
      (if (attrs :bbt) (begin
        (set! bars-per-section ((attrs :bbt) 0))
        (set! beats-per-bar ((attrs :bbt) 1))
        (set! ticks-per-beat ((attrs :bbt) 2))))

      (if (or (null? data) (odd? (length data)))
        (post "Error: score needs events in time/list pairs")
        (let store-event-loop ((time-event-assocs data))
          (let* ((time-arg    (car time-event-assocs))
                 (event-list  (cadr time-event-assocs))
                 ;ensure events always in a list 
                 (event-list  (if (list? (car event-list)) event-list (list event-list)))
                 (bar&tick    (time-arg->bar&tick time-arg))
                 (bar         (car bar&tick))
                 (tick        (cdr bar&tick))
                 (rest        (cddr time-event-assocs)))
            ;(post "do store-event" bar tick event-list)
            (store-event bar tick event-list) 
            ; update the bar-reader-index (so relative args can use it on next pass)
            (set! reader-bar-index bar) 
            (if (not-null? rest)
              (store-event-loop rest))))))

    (define (time-arg->bar&tick time-arg)
      "convert a number, offset sym, or bbt keyword to a bar&tick pair, updating reader-bar-index"
      (if (bbt? time-arg)
        ; case bbt
        (let* ((bars&ticks (bbt->bars&ticks beats-per-bar ticks-per-beat time-arg)))
          (cons (car bars&ticks) (cdr bars&ticks)))
        ; case not bbt (number, repeat, or offset)
        (let* ((time-str    (object->string time-arg))
               (is-repeat   (and (keyword? time-arg) (eq? #\. (time-str 1))))
               (is-offset   (and (keyword? time-arg) (eq? #\+ (time-str 1))))
               (offset      (if is-offset (string->number (substring time-str 2)) 0))
               (bar-actual  (cond
                              ((number? time-arg) time-arg)
                              (is-repeat          reader-bar-index)
                              (is-offset          (+ reader-bar-index offset))
                              ; if not number, repeat, or offset, assume it's a bbt
                              (else? 0))))
          (cons bar-actual 0))))

    ; store an event in the internal event data structure
    ; events is a hash of bar nums and bar-event lists 
    ; bar event lists of lists of ticks and events
    (define (store-event bar ticks event-list)
      ; (post "STORE-EVENT bar:" bar "tick:" ticks "event-list:" event-list)
      ; recursive iterator for going through the entires at a bar
      ; look for the right insertion point (by time) and either insert or alter if data already there
      (define (store-iter entries)
        (cond 
          ; if we got to end of events for bar, then we insert at end 
          ((null? entries)
            (cons (list ticks event-list) entries))
          ; if we found a matching entry (same ticks), alter the entry and return entries list
          ((= (entries 0 0) ticks)
            (let ((event-list-at-tick (entries 0 1)))
              (set! (entries 0 1) (append event-list-at-tick event-list))
              entries))
          ; if we got to an entry past this one, it's time to insert
          ((> (car (car entries)) ticks)
            (cons (list ticks event-list) entries)) 
          ; else keep going through the list
          (else
            (cons (car entries) (store-iter (cdr entries))))))
      ; update the event bar entry list
      (set! (events bar) (store-iter (or (events bar) '())))      
      ;(post "events now:" events)
    )

    (define (top-of-bar? tick-index)
      (= 0 (modulo tick-index (* ticks-per-beat beats-per-bar))))

    (define (stop)
      (post "score event stop")
      (cancel-delay cb-handle)
      (set! playing #f)
      (set! bar-index 0)
      (set! tick-index 0)
      #f)

    (define (start)
      (post "score event start")
      (set! playing #t)
      (run-tick))

    ; set the index to a bar and tick point
    (define (cue . args)
      ;(post "(cue)" args)
      (let ((bar  (car args))
            (tick (if (> (length args) 1) (args 1) 0)))
        (set! bar-index (dec bar))
        (set! tick-index tick)))

    (define (go time-arg)
      (let* ((bar&ticks (time-arg->bar&tick time-arg))
             (bar (car bar&ticks))
             (ticks (cdr bar&ticks)))
        (cue bar ticks)
        ; call tick for next pass directly (no scheduling)
        (run-tick)
        ; return #f to abort processing the rest of entries
        #f)) 

    (define (meter numer denom)
      (set! beats-per-bar numer)
      (send 'transport 'timesig numer denom))

    (define (tempo bpm)
      (send 'transport 'tempo bpm))

    (define (run-event evt)
      "execute an event entry"
      ;(post "run-event" evt)
      ; right now all events are lists that can be evaluated, may be expanded
      (eval evt))
   
    ; playback, normally called as (tick), but can be called with an
    ; arg of time to advance: (tick 120), etc
    (define (run-tick . args)
      ;(post "score (tick), bar-index:" bar-index "tick-index:" tick-index "args:" args)
      ; on top of bar, load this bar's events into events-for-bar 
      (if (top-of-bar? tick-index) (begin
        (set! bar-index (inc bar-index))
        (set! tick-index 0)
        (set! events-for-bar (events bar-index))
        (set! events-left (or events-for-bar '()))
        (post "bar index:" bar-index "events-for-bar:" events-for-bar)
      ))
      (let ((evt-res '()))
        ; now we consume events up until current time
        (while (not-null? events-left)
          (let* ((tick-events-entry (car events-left))
                 (entry-time (car tick-events-entry)))
            (if (<= entry-time tick-index)
              (begin
                (dolist (evt (cadr tick-events-entry)) 
                  ; run the event, if it returns #f, don't run anymore
                  (set! evt-res (run-event evt))
                  (if (not evt-res)
                    (break)))
                (set! events-left (cdr events-left)))
              (break))))  
        ; increment the tick-index unless we got a #f back from an event (stopping or jumping)
        (if evt-res 
          (if (null? args)
            (set! tick-index (+ tick-res tick-index)) 
            (set! tick-index (+ (args 0) tick-index))))
        ; reschedule if playing
        (if (and playing evt-res)
          (set! cb-handle (delay-tq tick-res tick-res run-tick))))
      ; return null 
      '())

    ; object boilerplate to allow getting and setting in object
    (define env (curlet))
 
    (define (get sym) 
      (if (keyword? sym) (attrs sym) (env sym)))
    
    (define (set sym val) 
      (if (keyword? sym) (set! (attrs sym) val) (set! (env sym) val))) 
    
    (define (post-events)
      (post "post-events")
      (post "events:" (env 'events)))
 
    ; call the constructor
    (init data)
    ;(post "events:" events)
    ; msg dispatcher, calls internal method matching symbol in msg
    (lambda (msg . args)
      (apply (eval msg) args)))
)


;********************************************************************************
; helper functions
(define (bbt->numbers bbt-sym)
  "convert bbt symbols in format :1-2-240 or :1:1:120 to (int-bars int-beats int-ticks)"
  (let ((p -1) (parts (list "" "" "0"))
        (chars (string->list (symbol->string bbt-sym)))) 
    (let char-loop ((char-index 0))
      (cond
        ((or (eq? (chars char-index) #\:) (eq? (chars char-index) #\-)) 
          (set! p (+ 1 p)))
        (else (set! (parts p) (string-append (parts p) (string (chars char-index))))))
      (if (< char-index (dec (length chars)))
        (char-loop (+ 1 char-index))))
    ; return parts, converted to numbers
    (map string->number parts)))

(define (bbt->bars&ticks beats-per-bar ticks-per-beat bbt-sym)
  ;(post "bbt->bars&ticks" beats-per-bar ticks-per-beat bbt-sym)
  (let* ((bbt-parts (bbt->numbers bbt-sym))
         (bar (bbt-parts 0))
         (ticks-beats (* ticks-per-beat (- (bbt-parts 1) 1.0)))
         (ticks-total (+ ticks-beats (bbt-parts 2))))
    ;(post "ticks-beats:" ticks-beats "ticks-total:" ticks-total)
    (cons bar (floor ticks-total))))

(define (bbt? arg)
  "return if a time arg is a bbt, which is a keyword with a numerical second char"
  (and (keyword? arg) (number? (string->number (substring (object->string arg) 1 2)))))


; convert bbt notation to ticks for use in the "at" macro below
(define (bbt->ticks beats-per-bar ticks-per-beat bbt-sym)
  ;(post "bbt->ticks" beats-per-bar ticks-per-beat bbt-sym)
  (let* ((bbt-parts (bbt->numbers bbt-sym))
         (ticks-bars (* beats-per-bar ticks-per-beat (- (bbt-parts 0) 1.0)))
         (ticks-beats (* ticks-per-beat (- (bbt-parts 1) 1.0)))
         (ticks-total (+ ticks-bars ticks-beats (bbt-parts 2))))
    ;(post "ticks-bars:" ticks-bars "ticks-beats:" ticks-beats "ticks-total:" ticks-total)
    (floor ticks-total)))


