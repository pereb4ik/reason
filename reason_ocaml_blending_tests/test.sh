#!/bin/sh

refmt='../_build/install/default/bin/refmt --print-width 50 --print re'
diff='git --no-pager diff --no-index --color=always'

function test() {
    filename=$1
    $refmt in/"$filename".re > out/"$filename".re
    $diff out/"$filename".re eout/"$filename".re
}

function test_rei() {
    filename=$1
    $refmt in/"$filename".rei > out/"$filename".rei
    $diff out/"$filename".rei eout/"$filename".rei
}

#facebook tests
test 'assert'
test 'basicStructures'
test 'bigarray'
test 'bucklescript'
test 'class_types'
test 'emptyFileComment'
test 'escapesInStrings'
test 'extensions'
test 'externals'
test 'features403'
test 'firstClassModules'
test 'fixme'
test 'functionInfix'
test 'if'
test 'infix'
test 'jsx'
test 'jsx_functor'
test 'lineComments'
test 'modules'
test 'modules_no_semi'
test 'object'
test 'pexpFun'
test 'pipeFirst'
test 'polymorphism'
test 'sharpop'
test 'singleLineCommentEof'
#test 'syntax' # he failed besause here used reserved match word
test 'testUtils'
test 'trailing'
test 'trailingSpaces'
test 'typeDeclarations'
test 'uncurried'
test 'variants'
test 'whitespace'
test 'wrappingTest'

$refmt in/ocaml_identifiers.ml > out/ocaml_identifiers.re
$diff out/ocaml_identifiers.re eout/ocaml_identifiers.re

test_rei 'syntax'
test_rei 'whitespace'
test_rei 'wrappingTest'

#read OCaml syntax, output Reason
test 'examplePatternMatching'
test 'forloop'
test 'ifelse'
test 'record'
