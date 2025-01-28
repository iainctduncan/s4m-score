(post "demo.scm loading")

(load-from-max "helpers.scm")
(load-from-max "cli.scm")
(load-from-max "s4m-score.scm")

(define (s4m-reset)
  (post "s4m-reset")
  (send 'transport 0)
  (send 'locate 0)
  (send 'metro 0)
  (delay 500 (lambda() (send 's4m-reset 'bang))))

(define (n num vel dur)
  ;(post "n" num vel dur)
  (out 0 (list num vel dur))
)

(define note-data (list 72 90 10))
(define (make-events)
  '(
    :3-1 ((n 48 90 120) (n 51 90 120))
    :3-3 ((n 48 90 120) (n 51 90 120))
   ))

#|
(define s (make-score-seq (hash-table :bbt '(8 4 480) :res 480) `(
  :1-1  ((n 60 90 120) (n 64 90 120))
  :1-2  (n 72 90 ,(+ 44 55))
  :1-3  (n ,@note-data)
  :2-1 ((n 36 90 120) (n 39 90 120))
  :2-3 ((n 36 90 120) (n 39 90 120))
  ,@(make-events)
)))
|#

(send 'transport 'tempo 120)
(define (tempo-env start ms end)
  (send 'tempo-line start)
  (send 'tempo-line end ms))

(define s (make-score-seq (hash-table :bbt '(8 4 480) :res 2) `(
  :1-1     ((send 'locate 0) (send 'transport 1) (send 'metro 'bang))
  :1-1     (n 60 90 120) 
  :1-2  (n 64 90 120)
  :1-3  (n 67 90 120)
  :1-4  (n 64 90 120)

  ;:2-1  (go :1-1)
  ;:2-1  (stop) 

  :2-1  (tempo-env 120 1000 60)

  :2-1  (n 48 90 120) 
  :2-2  (n 52 90 120)
  :2-3  (n 55 90 120)
  :2-4  (n 52 90 120)
  
  :3-1  (go :1-1)
  ;:3-1  (stop)

)))

(s 'cue 1 0)








(post (s 'get 'events))

