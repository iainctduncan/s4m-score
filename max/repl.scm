(post "am in on?")


(n 62 90 220)

(send 'transport 'timesig 3 4)
(send 'transport 'timesig 4 4)

(send 'transport 'tempo 60)

(send 'transport 1)
(send 'transport 0)


(define s (make-score (hash-table :bbt '(8 4 480) :res 960) `(
  :1-1-1  ((n 60 90 120) (n 62 90 120))
))) 

; get this working
(define s (make-score (hash-table :bbt '(8 4 480) :res 960) `(
  :1-1-2  (n ,note-num 90 ,(random 120))
; ,@( make-events )

)))

(define s (make-score (hash-table :bbt '(8 4 480) :res 960) 
  :1-1-1  play-c
;  :1-1-2  '(n 62 90 240)
))

(s 'start)
(s 'stop)

(s 'get-events)

(hash-table 1 ((0 (play-c play-e)) (480 (play-c play-e))))

(define e (s 'get 'events))

(e 1 0 1)
