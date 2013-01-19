# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)

require "newrelic_sequel/version"

Gem::Specification.new do |s|
  s.name     = "talentbox-newrelic-sequel"
  s.version  = NewRelicSequel::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors  = ["REA Group", "Metrilio S.A."]
  s.email    = [
    "yong.fu@rea-group.com",
    "wei.guangcheng@rea-group.com",
    "jonathan.tron@metrilio.com"
  ]
  s.homepage = "http://github.com/TalentBox/newrelic-sequel"
  s.summary  = "Sequel instrumentation for Newrelic."
  s.description = "Sequel instrumentation for Newrelic with sequel-rails and PostgreSQL CTE support"
  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]
  s.extra_rdoc_files = ["README.markdown"]
  s.rdoc_options = ["--charset=UTF-8"]

  s.add_runtime_dependency "sequel",  "> 3.22"
  s.add_runtime_dependency "newrelic_rpm", "~> 3.0"

  s.add_development_dependency "rake"
end
