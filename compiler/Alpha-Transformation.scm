;;;
;;; Alpha Transformation (Auxiliary Function)
;;;

(define-module Alpha-Transformation
  (use srfi-1)
  (use srfi-11)
  (use util.match)
  (require "./Basic-Utility")
  (require "./Id")
  (require "./Assoc")
  (require "./Propagation")
  (require "./Globals")
  (import Basic-Utility)
  (import Id)
  (import Assoc)
  (import Propagation)
  (import Globals)
  (export Alpha-Transform
          ))
(select-module Alpha-Transformation)

(define map-alpha-transform
  (lambda (A assoc)
    (map (lambda (x)
           (alpha-transform x assoc))
         A)))

(define alpha-transform
  (lambda (exp assoc)
    (match exp
      (() ())
      ((? boolean? bool) bool)
      ((? integer? int) int)
      ((? float? float) float)
      ((? var? var) (get-value var assoc))
      (('Cons A ((? not-global? w)) c)
       (let* ((new-A (map-alpha-transform A assoc))
              (new-w (gen-record))
              (new-assoc (assoc-adjoin w new-w assoc))
              (new-c (alpha-transform c new-assoc)))
         `(Cons ,new-A (,new-w) ,new-c)))
      (('Cons A ((? global? w)) c)
       (let* ((new-A (map-alpha-transform A assoc))
              (new-c (alpha-transform c assoc)))
         `(Cons ,new-A (,w) ,new-c)))
      (('Vector A ((? not-global? w)) c)
       (let* ((new-A (map-alpha-transform A assoc))
              (new-w (gen-record))
              (new-assoc (assoc-adjoin w new-w assoc))
              (new-c (alpha-transform c new-assoc)))
         `(Vector ,new-A (,new-w) ,new-c)))
      (('Vector A ((? global? w)) c)
       (let* ((new-A (map-alpha-transform A assoc))
              (new-c (alpha-transform c assoc)))
         `(Vector ,new-A (,w) ,new-c)))
      (('Select i A ((? not-global? w)) c)
       (let* ((new-i (alpha-transform i assoc))
              (new-A (alpha-transform A assoc))
              (new-w (gentmpv))
              (new-assoc (assoc-adjoin w new-w assoc))
              (new-c (alpha-transform c new-assoc)))
         `(Select ,new-i ,new-A (,new-w) ,new-c)))
      (('Select i A ((? global? w)) c)
       (let* ((new-i (alpha-transform i assoc))
              (new-A (alpha-transform A assoc))
              (new-c (alpha-transform c assoc)))
         `(Select ,new-i ,new-A (,w) ,new-c)))
      (('Alloc i v ((? not-global? w)) c)
       (let* ((new-i (alpha-transform i assoc))
              (new-v (alpha-transform v assoc))
              (new-w (gen-record))
              (new-assoc (assoc-adjoin w new-w assoc))
              (new-c (alpha-transform c new-assoc)))
         `(Alloc ,new-i ,new-v (,new-w) ,new-c)))
      (('Alloc i v ((? global? w)) c)
       (let* ((new-i (alpha-transform i assoc))
              (new-v (alpha-transform v assoc))
              (new-c (alpha-transform c assoc)))
         `(Alloc ,new-i ,new-v (,w) ,new-c)))
      (('Put i A v () c)
       (let* ((new-i (alpha-transform i assoc))
              (new-A (alpha-transform A assoc))
              (new-v (alpha-transform v assoc))
              (new-c (alpha-transform c assoc)))
         `(Put ,new-i ,new-A ,new-v () ,new-c)))
      (('Primop i A () c)
       (let* ((new-A (map-alpha-transform A assoc))
              (new-c (alpha-transform c assoc)))
         `(Primop ,i ,new-A () ,new-c)))
      (('Primop i A ((? not-global? w)) c)
       (let* ((new-A (map-alpha-transform A assoc))
              (new-w (gentmpv))
              (new-assoc (assoc-adjoin w new-w assoc))
              (new-c (alpha-transform c new-assoc)))
         `(Primop ,i ,new-A (,new-w) ,new-c)))
      (('Primop i A ((? global? w)) c)
       (let* ((new-A (map-alpha-transform A assoc))
              (new-c (alpha-transform c assoc)))
         `(Primop ,i ,new-A (,w) ,new-c)))
      (('If t tc fc)
       (let ((new-t (alpha-transform t assoc))
             (new-tc (alpha-transform tc assoc))
             (new-fc (alpha-transform fc assoc)))
         `(If ,new-t ,new-tc ,new-fc)))
      (('Fix B A)
       (let* ((new-assoc (assoc-extend (map car B)
                                       (gentmpf-list (length B))
                                       assoc))
              (new-B (map (match-lambda
                           ((f V C)
                            (let* ((new-f (get-value f new-assoc))
                                   (new-V (gentmpv-list (length V)))
                                   (new-new-assoc (assoc-extend V new-V new-assoc))
                                   (new-C (alpha-transform C new-new-assoc)))
                              `(,new-f ,new-V ,new-C))))
                          B))
              (new-A (alpha-transform A new-assoc)))
         `(Fix ,new-B ,new-A)))
      (('Fix2 B A)
       (let* ((new-assoc (assoc-extend (map car B)
                                       (gentmpr-list (length B))
                                       assoc))
              (new-B (map (match-lambda
                           ((f V C)
                            (let* ((new-f (get-value f new-assoc))
                                   (new-V (gentmpv-list (length V)))
                                   (new-new-assoc (assoc-extend V new-V new-assoc))
                                   (new-C (alpha-transform C new-new-assoc)))
                              `(,new-f ,new-V ,new-C))))
                          B))
              (new-A (alpha-transform A new-assoc)))
         `(Fix2 ,new-B ,new-A)))
      (('Apply f A)
       (let ((new-f (alpha-transform f assoc))
             (new-A (map-alpha-transform A assoc)))
         `(Apply ,new-f ,new-A)))
      (('Set v ((? not-global? w)) c)
       (let* ((new-v (alpha-transform v assoc))
              (new-w (gentmpv))
              (new-assoc (assoc-adjoin w new-w assoc))
              (new-c (alpha-transform c new-assoc)))
         `(Set ,new-v (,new-w) ,new-c)))
      (('Set v ((? global? w)) c)
       (let* ((new-v (alpha-transform v assoc))
              (new-c (alpha-transform c assoc)))
         `(Set ,new-v (,w) ,new-c)))
      (else (errorf "~s : no match expressin : ~s\n" "alpha-transform" exp)))))

(define Alpha-Transform
  (lambda (program)
    (alpha-transform program init-assoc)))

(provide "Alpha-Transformation")