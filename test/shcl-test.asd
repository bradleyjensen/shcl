(defsystem "shcl-test"
  :class :package-inferred-system
  :description "Shcl tests, tests for a lisp shell"
  :version "0.0.1"
  :author "Brad Jensen <brad@bradjensen.net>"
  :licence "All rights reserved."
  :depends-on ("prove"
               "shcl"
               "shcl-test/lexer"
               "shcl-test/utility"
               "shcl-test/environment"
               "shcl-test/posix"
               "shcl-test/lisp-interpolation"
               "shcl-test/data"))
