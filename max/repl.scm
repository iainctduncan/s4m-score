(post "am in on?")


(n 62 90 220)

(send 'transport 'timesig 3 4)
(send 'transport 'timesig 4 4)

(send 'transport 'tempo 60)

(send 'transport 1)
(send 'transport 0)

(begin
  (send 'transport 'tempo 120)
  (delay-tq 960 960 (lambda()(n 60 90 120)))
  (send 'transport 'tempo 240)
)

(begin
  (send 'transport 'tempo 120)
  (delay-tq 960 960 (lambda()(n 60 90 120)))
  (send 'transport 'tempo 30)
)

(set-tempo 120)

(n 60 90 120)

