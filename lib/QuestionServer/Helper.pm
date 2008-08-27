package QuestionServer::Helper;

use MIME::Base64 qw( encode_base64 decode_base64);

sub BuildTranslator {  
    #Create Translator Object
    my $translator = WeBWorK::PG::Translator->new;
    my @modules = @{$QuestionServer::Settings->{PG}->{modules}};
 
    #Evaulate all module packs
    foreach my $module_packages_ref (@modules) {
      my $module = $module_packages_ref->{module};
      # the first item is the main package
      $translator->evaluate_modules($module);
      if (defined($module_packages_ref->{packages})) {
        my $packages = $module_packages_ref->{packages};
        # the remaining items are "extra" packages
        $translator->load_extra_packages(@{$packages});
      }
    }    
    return $translator;
}

sub BuildImageGenerator { 
    my $image_generator = WeBWorK::PG::ImageGenerator->new(
        tempDir => $QuestionServer::Settings->{Paths}->{Tmp}, # global temp dir
        latex   => $QuestionServer::Settings->{Paths}->{latex},
        dvipng => $QuestionServer::Settings->{Paths}->{dvipng},
        useCache => $QuestionServer::Settings->{ImageGenerator}->{UseCache},
        cacheDir => $QuestionServer::Settings->{Paths}->{HtdocsTmpEquations},
        cacheURL => $QuestionServer::Settings->{URLs}->{HtdocsTmpEquations},
        cacheDB => "",
        useMarkers => 0,
        dvipng_align =>$QuestionServer::Settings->{ImageGenerator}->{Alignment},
    );
    #DEFINE CLOSURE CLASS FOR IMAGE GENERATOR
    #$self->{problemEnviron}{imagegen} = new ProblemServer::Utils::RestrictedClosureClass($image_generator, "add");
    return $image_generator;
}

sub RunTranslator {
    my ($translator,$imagegenerator,$source,$environment) = @_;
    
    $source = decode_base64($source);
    #copy the defaults to this instance
    my %env = %{$QuestionServer::Settings->{ProblemEnvironment}};
    my $envref = \%env;
    #update with the instances from the passed in environment
    while ( my($key, $value) = each(%$environment) ) {
        $envref->{$key}= $value;
    }
    $envref->{imagegen} = new QuestionServer::RestrictedClosureClass($imagegenerator, "add");
    #return $environment;  
    #$translator->{safe} = new Safe;
    $translator->{envir} = undef;
    $translator->{safe} = new Safe();
    $translator->environment($envref);

    $translator->initialize();

    eval{$translator->pre_load_macro_files(new Safe(),$QuestionServer::Settings->{Paths}->{PGMacros},'PG.pl', 'dangerousMacros.pl', 'IO.pl', 'PGbasicmacros.pl', 'PGanswermacros.pl')};
    #return $QuestionServer::Settings->{Paths}->{PGMacros};
    foreach (qw(PG.pl dangerousMacros.pl IO.pl)) {
        my $macroPath = $QuestionServer::Settings->{Paths}->{PGMacros} . "/$_";
        my $err = $translator->unrestricted_load($macroPath);
        warn "Error while loading $macroPath: $err" if $err;
    }

    $translator->set_mask();

    eval { $translator->source_string( $source ) }; 
    $@ and die("bad source");

    $translator->rf_safety_filter(\&QuestionServer::Helper::NullSafetyFilter);

    $translator->translate();

    return $translator;    
}

sub CheckAnswers {
    my ($translator,$imagegenerator,$answerArray) = @_;
 
    my $answerHash = {};
    for(my $i=0;$i<@{$answerArray};$i++) {
        $answerHash->{decode_base64($answerArray->[$i]{field})} = decode_base64($answerArray->[$i]{answer});
    }
    $translator->process_answers($answerHash);
 
    # retrieve the problem state and give it to the translator
    #warn "PG: retrieving the problem state and giving it to the translator\n";
    $translator->rh_problem_state({
        recorded_score => "0",
        num_of_correct_ans => "0",
        num_of_incorrect_ans => "0",
    });
 
    # determine an entry order -- the ANSWER_ENTRY_ORDER flag is built by
    # the PG macro package (PG.pl)
    #warn "PG: determining an entry order\n";
    my @answerOrder = $translator->rh_flags->{ANSWER_ENTRY_ORDER}
        ? @{ $translator->rh_flags->{ANSWER_ENTRY_ORDER} }
        : keys %{ $translator->rh_evaluated_answers };
 
 
    # install a grader -- use the one specified in the problem,
    # or fall back on the default from the course environment.
    # (two magic strings are accepted, to avoid having to
    # reference code when it would be difficult.)
    #warn "PG: installing a grader\n";
    my $grader = $translator->rh_flags->{PROBLEM_GRADER_TO_USE};
    $grader = $translator->rf_std_problem_grader if $grader eq "std_problem_grader";
    $grader = $translator->rf_avg_problem_grader if $grader eq "avg_problem_grader";
    die "Problem grader $grader is not a CODE reference." unless ref $grader eq "CODE";
    $translator->rf_problem_grader($grader);
 
    # grade the problem
    #warn "PG: grading the problem\n";
    my ($result, $state) = $translator->grade_problem(
        answers_submitted => 1,
        ANSWER_ENTRY_ORDER => \@answerOrder,
        %{$answerHash} #FIXME? this is used by sequentialGrader is there a better way?
    );
 
    my $answers = $translator->rh_evaluated_answers;
    my $key;
    my $preview;
    my $answerResponse = {};
    my @answersArray;
 
    foreach $key (keys %{$answers}) {
        #PREVIEW GENERATOR
        $preview = $answers->{"$key"}->{"preview_latex_string"};
        $preview = "" unless defined $preview and $preview ne "";
 
        $preview = $imagegenerator->add($preview);
 
        #ANSWER STRUCT
        $answerResponse = {};
        $answerResponse->{field} = encode_base64($key);
        $answerResponse->{answer} = encode_base64($answers->{"$key"}->{"original_student_ans"});
        $answerResponse->{answer_msg} = encode_base64($answers->{"$key"}->{"ans_message"});
        $answerResponse->{correct} = encode_base64($answers->{"$key"}->{"correct_ans"});
        $answerResponse->{score} = $answers->{"$key"}->{"score"};
        $answerResponse->{evaluated} = encode_base64($answers->{"$key"}->{"student_ans"});
        $answerResponse->{preview} = encode_base64($preview);
        push(@answersArray, $answerResponse);
    }
    return \@answersArray;
}

sub RunImageGenerator {
    my($imagegenerator) = @_;
    $imagegenerator->render();
}

sub BuildQuestionResponse {
    my ($translator) = @_;
    my $response = {};
    $response->{errors} = $translator->errors;
    $response->{output} = encode_base64(${$translator->r_text});
    $response->{seed} = 'asd';#$translator->{envir};
    $response->{grading} = $translator->rh_flags->{showPartialCorrectAnswers};
    return $response;
}

sub NullSafetyFilter {
  return shift, 0; # no errors
}

1;

