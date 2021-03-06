package QuestionServer;

use YAML::XS qw(LoadFile);
use Safe;


#what needs to be done at initialization
BEGIN {
	$main::VERSION = "2.3.2";
	die 'RootPath needs to be defined' unless (defined($QuestionServer::RootPath));
	my $yaml = LoadFile($QuestionServer::RootPath . '/config/global.yml');
	#my $hostname = $yaml->{QuestionServer}->{Host}
	$QuestionServer::Settings = $yaml;	
	$QuestionServer::Settings->{Paths}->{Root} = $QuestionServer::RootPath;
	$QuestionServer::Settings->{Paths}->{Htdocs} = $QuestionServer::RootPath . '/htdocs';
    $QuestionServer::Settings->{Paths}->{Tmp} = $QuestionServer::RootPath . '/tmp';
    $QuestionServer::Settings->{Paths}->{HtdocsTmpEquations} = $QuestionServer::RootPath . '/htdocs/tmp/equations';
    $QuestionServer::Settings->{Paths}->{PGMacros} = $QuestionServer::Settings->{Paths}->{PG} . '/macros';
    $QuestionServer::Settings->{URLs}->{HtdocsTmpEquations} = $QuestionServer::Settings->{URLs}->{Base} . $QuestionServer::Settings->{URLs}->{Files} . '/tmp/equations';

    $QuestionServer::Settings->{PG}->{Directories} = {};
    $QuestionServer::Settings->{PG}->{Directories}->{root} = $QuestionServer::Settings->{Paths}->{PG};
    $QuestionServer::Settings->{PG}->{Directories}->{macros} = $QuestionServer::Settings->{Paths}->{PGMacros};
    $QuestionServer::Settings->{PG}->{Directories}->{lib} = $QuestionServer::Settings->{Paths}->{PG} . '/lib';
    $QuestionServer::Settings->{PG}->{Directories}->{macrosPath} = [$QuestionServer::Settings->{Paths}->{PGMacros}];


    $QuestionServer::Settings->{ProblemEnvironment}->{pgDirectories} = $QuestionServer::Settings->{PG}->{Directories};
    $QuestionServer::Settings->{ProblemEnvironment}->{__files__} = {
        root => $QuestionServer::Settings->{Paths}->{PG},
        pg =>  $QuestionServer::Settings->{Paths}->{PG},
        tmpl => $QuestionServer::Settings->{Paths}->{PG},   
    };
    
    my $pg_path = $QuestionServer::Settings->{Paths}->{PG};

    eval "use lib '$pg_path/lib'"; die $@ if $@;
    eval "use WeBWorK::PG::Translator"; die $@ if $@;
    eval "use WeBWorK::PG::ImageGenerator"; die $@ if $@;

    eval "use QuestionServer::Helper"; die $@ if $@;
    eval "use QuestionServer::RestrictedClosureClass"; die $@ if $@;

}


sub hello {
    return "hello world";
}

sub RenderQuestion {
    my ($self,$request) = @_;
    my $translator = QuestionServer::Helper::BuildTranslator();
    my $imagegenerator = QuestionServer::Helper::BuildImageGenerator();
    QuestionServer::Helper::RunTranslator($translator,$imagegenerator,$request->{code},$request->{env});
    QuestionServer::Helper::RunImageGenerator($translator,$imagegenerator);
    return QuestionServer::Helper::BuildQuestionResponse($translator);
}

sub RenderQuestionAndCheckAnswers {
    my ($self,$request,$answers) = @_;
    my $translator = QuestionServer::Helper::BuildTranslator();
    my $imagegenerator = QuestionServer::Helper::BuildImageGenerator();
    QuestionServer::Helper::RunTranslator($translator,$imagegenerator,$request->{code},$request->{env});
    QuestionServer::Helper::RunImageGenerator($translator,$imagegenerator);
    my $response = {};
    $response->{answers} = QuestionServer::Helper::CheckAnswers($translator,$imagegenerator,$answers);
    $response->{question} = BuildQuestionResponse($translator);
    return $response;
}

1;
