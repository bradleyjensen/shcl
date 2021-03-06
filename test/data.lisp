;; Copyright 2018 Bradley Jensen
;;
;; Licensed under the Apache License, Version 2.0 (the "License");
;; you may not use this file except in compliance with the License.
;; You may obtain a copy of the License at
;;
;;     http://www.apache.org/licenses/LICENSE-2.0
;;
;; Unless required by applicable law or agreed to in writing, software
;; distributed under the License is distributed on an "AS IS" BASIS,
;; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;; See the License for the specific language governing permissions and
;; limitations under the License.

(defpackage :shcl/test/data
  (:use :common-lisp :prove :shcl/core/utility :shcl/core/data
        :shcl/test/foundation)
  (:import-from :fset))
(in-package :shcl/test/data)

(optimization-settings)

(link-package-to-system :shcl/core/data)

(define-data base ()
  ((a
    :initarg :a
    :initform nil
    :reader base-a
    :writer unsafe-set-base-a)))

(define-cloning-setf-expander base-a
    unsafe-set-base-a)

(define-data derived (base)
  ((b
    :initarg :b
    :initform nil
    :reader derived-b
    :writer unsafe-set-derived-b)))

(define-cloning-setf-expander derived-b
    unsafe-set-derived-b)

(define-data derived-b (base)
  ((c
    :initarg :c
    :initform nil
    :reader derived-c
    :writer unsafe-set-derived-c)))

(define-cloning-setf-expander derived-c
    unsafe-set-derived-c)

(defclass vanilla ()
  ((a
    :initarg :a
    :initform nil)))

(define-test basics
  (let* ((base (make-instance 'base :a 123))
         (derived (make-instance 'derived :a 456 :b 789))
         (cons (cons base derived)))
    (ok (equal 123 (base-a base))
        "Readers work")
    (ok (equal 456 (base-a derived))
        "Readers work on subclasses")

    (let ((old-base base))
      (setf (base-a base) 'a)
      (ok (not (eq base old-base))
          "Post update, new value is not eq to old value")
      (ok (not (eql (base-a base) (base-a old-base)))
          "Post update, contained value is different")
      (setf base old-base))

    (let ((old-base base)
          (old-cons cons))
      (setf (base-a (car cons)) 'a)
      (ok (eq old-cons cons)
          "Non-data intermediate places are not cloned")
      (ok (and (eq old-base base)
               (equal (base-a old-base) 123)
               (not (eq old-base (car cons))))
          "All existing pointers to data are unaffected by an update")
      (setf (car cons) old-base))

    (let ((old-base base)
          (base base))
      (setf (base-a base) base)
      (ok (and (not (eq base old-base))
               (eq (base-a base) old-base)
               (equal (base-a old-base) 123))
          "Circularity isn't confusing"))))

(define-test inheritance
  (is-error (eval '(define-data bad-data (vanilla) ())) 'error
            "Inheriting from a normal class is an error")
  (is-error (eval '(defclass bad-class (base) ())) 'error
            "Inheriting from a data class in a normal class is an error"))

(define-data numbers ()
  ((a
    :initarg :a
    :initform 0
    :reader numbers-a
    :writer unsafe-set-numbers-a)
   (b
    :initarg :b
    :initform 0
    :reader numbers-b
    :writer unsafe-set-numbers-b)))

(define-cloning-setf-expander numbers-a
    unsafe-set-numbers-a)

(define-cloning-setf-expander numbers-b
    unsafe-set-numbers-b)

(define-data numbers-c (numbers)
  ((c
    :initarg :c
    :initform 0
    :reader numbers-c
    :writer unsafe-set-numbers-c)))

(define-cloning-setf-expander numbers-c
    unsafe-set-numbers-c)

(define-data numbers-d (numbers)
  ((d
    :initarg :d
    :initform 0
    :reader numbers-d
    :writer unsafe-set-numbers-d)))

(define-cloning-setf-expander numbers-d
    unsafe-set-numbers-d)

(define-data unset-slots ()
  ((a
    :initarg :a)
   (b
    :initarg :b)))

(define-test ordering
  (let ((a (make-instance 'numbers :a 123 :b 123))
        (b (make-instance 'numbers :a 123 :b 123)))
    (is (fset:compare a b) :equal
        "Non-eq data classes are equal")
    (setf (numbers-a a) 122)
    (is (fset:compare a b) :less
        "Compare works for first slot differences")
    (setf (numbers-a a) 123)
    (setf (numbers-b a) 124)
    (is (fset:compare a b) :greater
        "Compare works for second slot differences")
    (setf (numbers-b a) 123)

    (setf b (make-instance 'numbers-c :a 123 :b 123 :c 123))
    (is (fset:compare a b) :less
        "Base classes are less than derived classes")
    (setf (numbers-a a) 124)
    (is (fset:compare a b) :greater
        "Base classes can be greater than derived classes")
    (setf (numbers-a a) 122)
    (is (fset:compare a b) :less
        "Derived classes can be greater than base classes")

    (setf a (make-instance 'numbers-d :a 123 :b 123 :d 0))
    (setf b (make-instance 'numbers-c :a 123 :b 123 :c 1))
    (is (fset:compare a b) :unequal
        "Different derived classes are unequal")
    (setf (numbers-a a) 124)
    (is (fset:compare a b) :greater
        "Different direved clases can be ordered")

    (setf a (make-instance 'unset-slots :a 123 :b 123))
    (setf b (make-instance 'unset-slots :b 456))
    (is (fset:compare a b) :greater
        "Unbound slots are always less than bound slots")
    (setf a (make-instance 'unset-slots :b 456))
    (setf b (make-instance 'unset-slots :a 123 :b 123))
    (is (fset:compare a b) :less
        "Unbound slots are always less than bound slots")
    (setf a (make-instance 'unset-slots :b 456))
    (setf b (make-instance 'unset-slots :b 456))
    (is (fset:compare a b) :equal
        "Unbound slots are equal to bound slots")))

(defvar *clone-test-class-a-counter* 0)
(defvar *clone-test-class-b-counter* 0)

(defclass clone-test-class ()
  ((a
    :initform (incf *clone-test-class-a-counter*)
    :initarg :a)
   (b
    :initform (incf *clone-test-class-b-counter*)
    :initarg :b)))

(define-clone-method clone-test-class)

(define-test clone
  (let* ((*clone-test-class-a-counter* 0)
         (*clone-test-class-b-counter* 0)
         (instance (make-instance 'clone-test-class :a 100 :b 200))
         clone)
    (is *clone-test-class-a-counter* 0
        "Initforms haven't run yet")
    (is *clone-test-class-b-counter* 0
        "Initforms haven't run yet")

    (setf clone (clone instance))

    (is *clone-test-class-a-counter* 0
        "Initforms haven't run yet")
    (is *clone-test-class-b-counter* 0
        "Initforms haven't run yet")
    (ok (not (eq instance clone))
        "The clone is a different instance")
    (is (slot-value clone 'a) (slot-value instance 'a)
        "The clone has the same slot values")
    (is (slot-value clone 'b) (slot-value instance 'b)
        "The clone has the same slot values")

    (setf clone (clone instance :a 123))

    (is (slot-value clone 'a) 123
        "clone respected initargs")
    (ok (not (equal (slot-value instance 'a) 123))
        "The original wasn't modified")
    (is (slot-value clone 'b) (slot-value instance 'b)
        "Slots that weren't initarg'd have the same value")))
