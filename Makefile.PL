use ExtUtils::MakeMaker;

WriteMakefile(
	NAME => "Data::ID::Exim",
	VERSION_FROM => "lib/Data/ID/Exim.pm",
	PREREQ_PM => {
		"Time::HiRes" => "1.00",
	},
);
