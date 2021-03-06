;;;
;;; Machine-code-Generation
;;;

(define-module Machine-code-Generation-32
  (use srfi-1)
  (use srfi-11)
  (use util.match)
  (require "./Basic-Utility")
  (require "./Id")
  (require "./CPS-Language")
  (import Basic-Utility)
  (import Id)
  (import CPS-Language)
  (export Generate-Machine-code
          ))
(select-module Machine-code-Generation-32)

;; Special Registers
;;
;; s0 : heap pointer
;; s1 : initial stack top
;;

(define imd?
  (lambda (x)
    (or (not (var? x))
        (let ((s (x->string x)))
          (char=? (string-ref s 0) #\L)))))

(define generate-machine-code
  (lambda (exp)
    (match exp
      (() '((halt)))
      ((? boolean? bool) '((halt)))
      ((? integer? int) '((halt)))
      ((? float? float) '((halt)))
      ((? var? var) '((halt)))
      (('Cons A (w) c)
       (append `((set reg ,w s0)
                 (+ imd s0 s0 ,(length A)))
               (let loop ((A A)
                          (i 0))
                 (if (null? A)
                     (generate-machine-code c)
                     (let ((a (car A)))
                       (if (imd? a)
                           (append `((set imd h0 ,a)
                                     (store h0 ,w ,i))
                                   (loop (cdr A) (+ i 1)))
                           (append `((store ,a ,w ,i))
                                   (loop (cdr A) (+ i 1)))))))))
      (('Vector A (w) c)
       (append `((set reg ,w s0)
                 (+ imd s0 s0 ,(length A)))
               (let loop ((A A)
                          (i 0))
                 (if (null? A)
                     (generate-machine-code c)
                     (let ((a (car A)))
                       (if (imd? a)
                           (append `((set imd h0 ,a)
                                     (store h0 ,w ,i))
                                   (loop (cdr A) (+ i 1)))
                           (append `((store ,a ,w ,i))
                                   (loop (cdr A) (+ i 1)))))))))
      (('Stack s A (w) c)
       (append `((- imd ,w ,s ,(length A)))
               (let loop ((A A)
                          (i 0))
                 (if (null? A)
                     (generate-machine-code c)
                     (let ((a (car A)))
                       (if (imd? a)
                           (append `((set imd h0 ,a)
                                     (store h0 ,w ,i))
                                   (loop (cdr A) (+ i 1)))
                           (append `((store ,a ,w ,i))
                                   (loop (cdr A) (+ i 1)))))))))
      (('Select (? imd? i) A (w) c)
       (append `((load imd ,w ,A ,i)) (generate-machine-code c)))
      (('Select i (? imd? A) (w) c)
       (append `((load imd ,w ,i ,A)) (generate-machine-code c)))
      (('Select i A (w) c)
       (append `((load reg ,w ,A ,i)) (generate-machine-code c)))
      (('Alloc (? imd? i) (? imd? v) (w) c)
       (append `((set imd h2 ,v)
                 (set reg ,w s0)
                 (+ imd s0 s0 ,i))
               (append (let ((loop (gen-alloc-label))
                             (end (gen-alloc-label)))
                         `((set imd h0 ,(+ i 1))
                           ,loop
                           (= imd h1 h0 0)
                           (if reg h1)
                           (goto imd ,end)
                           (- imd h0 h0 1)
                           (+ reg h1 ,w h0)
                           (store h2 h1 0)
                           (goto imd ,loop)
                           ,end))
                       (generate-machine-code c))))
      (('Alloc (? imd? i) v (w) c)
       (append `((set reg ,w s0)
                 (+ imd s0 s0 ,i))
               (append (let ((loop (gen-alloc-label))
                             (end (gen-alloc-label)))
                         `((set imd h0 ,(+ i 1))
                           ,loop
                           (= imd h1 h0 0)
                           (if reg h1)
                           (goto imd ,end)
                           (- imd h0 h0 1)
                           (+ reg h1 ,w h0)
                           (store ,v h1 0)
                           (goto imd ,loop)
                           ,end))
                       (generate-machine-code c))))
      (('Alloc i (? imd? v) (w) c)
       (append `((set imd h2 ,v)
                 (set reg ,w s0)
                 (+ reg s0 s0 ,i))
               (append (let ((loop (gen-alloc-label))
                             (end (gen-alloc-label)))
                         `((+ imd h0 ,i 1)
                           ,loop
                           (= imd h1 h0 0)
                           (if reg h1)
                           (goto imd ,end)
                           (- imd h0 h0 1)
                           (+ reg h1 ,w h0)
                           (store h2 h1 0)
                           (goto imd ,loop)
                           ,end))
                       (generate-machine-code c))))
      (('Alloc i v (w) c)
       (append `((set reg ,w s0)
                 (+ reg s0 s0 ,i))
               (append (let ((loop (gen-alloc-label))
                             (end (gen-alloc-label)))
                         `((+ imd h0 ,i 1)
                           ,loop
                           (= imd h1 h0 0)
                           (if reg h1)
                           (goto imd ,end)
                           (- imd h0 h0 1)
                           (+ reg h1 ,w h0)
                           (store ,v h1 0)
                           (goto imd ,loop)
                           ,end))
                       (generate-machine-code c))))
      (('Put (? imd? i) A (? imd? v) () c)
       (append `((set imd h0 ,v)
                 (store h0 ,A ,i))
               (generate-machine-code c)))
      (('Put (? imd? i) A v () c)
       (append `((store ,v ,A ,i))
               (generate-machine-code c)))
      (('Put i A (? imd? v) () c)
       (append `((set imd h0 ,v)
                 (+ reg h1 ,A ,i)
                 (store h0 h1 0))
               (generate-machine-code c)))
      (('Put i A v () c)
       (append `((+ reg h0 ,A ,i)
                 (store ,v h0 0))
               (generate-machine-code c)))
      (('Offset (? imd? i) A (w) c)
       (cons
        (cond
         ((< i 0) `(- imd ,w ,A ,(- 0 i)))
         ((= i 0) `(set imd ,w ,A))
         ((> i 0) `(+ imd ,w ,A ,i)))
        (generate-machine-code c)))
      (('Offset i A (w) c)
       (append `((+ reg ,w ,A ,i))
               (generate-machine-code c)))
      (('Primop i () () c)
       (append `((,i))
               (generate-machine-code c)))
      (('Primop i () (w) c)
       (append `((,i ,w))
               (generate-machine-code c)))
      (('Primop i ((? imd? a)) () c)
       (append `((,i imd ,a))
               (generate-machine-code c)))
      (('Primop i (a) () c)
       (append `((,i reg ,a))
               (generate-machine-code c)))
      (('Primop i ((? imd? a)) (w) c)
       (cons `(set imd h0 ,a)
             (cons (match i
                     ('lognot `(not reg ,w h0))
                     ('null? 'cannot-implemented)
                     ('boolean? 'cannot-implemented)
                     ('pair? 'cannot-implemented)
                     ('symbol? 'cannot-implemented)
                     ('integer? 'cannot-implemented)
                     ('real? 'cannot-implemented)
                     ('char? 'cannot-implemented)
                     ('string? 'cannot-implemented)
                     ('vector? 'cannot-implemented)
                     ('port? 'cannot-implemented)
                     ('procedure? 'cannot-implemented)
                     (else `(,i reg ,w h0)))
                   (generate-machine-code c))))
      (('Primop i (a) (w) c)
       (cons (match i
               ('lognot `(not reg ,w ,a))
               ('null? 'cannot-implemented)
               ('boolean? 'cannot-implemented)
               ('pair? 'cannot-implemented)
               ('symbol? 'cannot-implemented)
               ('integer? 'cannot-implemented)
               ('real? 'cannot-implemented)
               ('char? 'cannot-implemented)
               ('string? 'cannot-implemented)
               ('vector? 'cannot-implemented)
               ('port? 'cannot-implemented)
               ('procedure? 'cannot-implemented)
               (else `(,i reg ,w ,a)))
             (generate-machine-code c)))
      (('Primop i (a (? imd? b)) (w) c)
       (cons (match i
               ('logand `(and imd ,w ,a ,b))
               ('logor `(or imd ,w ,a ,b))
               ('logxor `(xor imd ,w ,a ,b))
               (else `(,i imd ,w ,a ,b)))
             (generate-machine-code c)))
      (('Primop (? commutative-primop? i) ((? imd? a) b) (w) c)
       (cons (match i
               ('logand `(and imd ,w ,b ,a))
               ('logor `(or imd ,w ,b ,a))
               ('logxor `(xor imd ,w ,b ,a))
               (else `(,i imd ,w ,b ,a)))
             (generate-machine-code c)))
      (('Primop i ((? imd? a) b) (w) c)
       (append `((set imd h0 ,a)
                 (,i reg ,w h0 ,b))
               (generate-machine-code c)))
      (('Primop i (a b) (w) c)
       (cons (match i
               ('logand `(and reg ,w ,a ,b))
               ('logor `(or reg ,w ,a ,b))
               ('logxor `(xor reg ,w ,a ,b))
               (else `(,i reg ,w ,a ,b)))
             (generate-machine-code c)))
      (('If (? imd? t) tc fc)
       (let ((tl (gen-if-label))
             (fl (gen-if-label)))
         (append `((if imd ,t)
                   (goto imd ,tl)
                   (goto imd ,fl))
                 (cons tl (generate-machine-code tc))
                 (cons fl (generate-machine-code fc)))))
      (('If t tc fc)
       (let ((tl (gen-if-label))
             (fl (gen-if-label)))
         (append `((if reg ,t)
                   (goto imd ,tl)
                   (goto imd ,fl))
                 (cons tl (generate-machine-code tc))
                 (cons fl (generate-machine-code fc)))))
      (('Apply (? imd? f) _)
       `((call imd ,f)))
      (('Apply f _)
       `((call reg ,f)))
      (('Set (? imd? v) (w) c)
       (append `((set imd ,w ,v))
               (generate-machine-code c)))
      (('Set v (w) c)
       (append `((set reg ,w ,v))
               (generate-machine-code c)))
      (else (errorf "~s : no match expressin : ~s\n" "register-assignment" exp)))))

(define Generate-Machine-code
  (lambda (program)
    (format (standard-error-port) "Start Machine-code-Generation-32...\n")
    (match program
      (('Fix F M)
       (let ((new-F (append-map (match-lambda
                                 ((l _ B)
                                  (cons l (generate-machine-code B))))
                                F))
             (new-M (append `(main (set imd s0 ,(* 1024 512)) (set imd s1 ,(- (* 1024 1024) 1))) (generate-machine-code M))))
         (append new-M new-F))))))

(provide "Machine-code-Generation-32")
