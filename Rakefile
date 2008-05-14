require "rake"
require "rake/testtask"
require "rake/rdoctask"
require "rake/gempackagetask"
require "spec/rake/spectask"

require "rake/clean"

NAME = "atom-tools"
VERS = "2.0.0"

# the following from markaby-0.5's tools/rakehelp
def setup_tests
  Rake::TestTask.new do |t|
    t.libs << "test"
    t.test_files = FileList['test/test*.rb']
    t.verbose = true
  end
end

def setup_rdoc files
  Rake::RDocTask.new do |rdoc|
    rdoc.title = NAME + " documentation"
    rdoc.rdoc_dir = 'doc'
    rdoc.options << '--line-numbers'
    rdoc.options << '--inline-source'
    rdoc.rdoc_files.add(files)
  end
end

def setup_gem(pkg_name, pkg_version, author, summary, dependencies, test_file)
  pkg_version = pkg_version
  pkg_name    = pkg_name
  pkg_file_name = "#{pkg_name}-#{pkg_version}"

  spec = Gem::Specification.new do |s|
    s.name = pkg_name
    s.version = pkg_version
    s.platform = Gem::Platform::RUBY
    s.author = author
    s.email = 'whateley@gmail.com'
    s.homepage = 'http://code.necronomicorp.com'
    s.rubyforge_project = 'ibes'
    s.summary = summary
    s.test_file = test_file
    s.has_rdoc = true
    s.extra_rdoc_files = [ "README" ]
    dependencies.each do |dep|
        s.add_dependency(*dep)
    end
    s.files = %w(COPYING README Rakefile setup.rb) +
    Dir.glob("{bin,doc,test,lib}/**/*") + 
    Dir.glob("ext/**/*.{h,c,rb}") +
    Dir.glob("examples/**/*.rb") +
    Dir.glob("tools/*.rb")

    s.require_path = "lib"
    s.extensions = FileList["ext/**/extconf.rb"].to_a

    s.bindir = "bin"
  end

  Rake::GemPackageTask.new(spec) do |p|
    p.gem_spec = spec
    p.need_tar = true
  end

  task :install do
    sh %{rake package}
    sh %{gem install pkg/#{pkg_name}-#{pkg_version}}
  end
end

task :default => [:spec]
desc 'Run all specs and generate report for spec results and code coverage'
Spec::Rake::SpecTask.new('spec') do |t| 
  t.spec_opts = ["--format", "html:report.html", '--diff'] 
  t.fail_on_error = false
  t.rcov = true
end

setup_tests
setup_rdoc ['README', 'lib/**/*.rb']

summary = "Tools for working with Atom Entries, Feeds and Collections"
test_file = "test/runtests.rb"
setup_gem(NAME, VERS, "Brendan Taylor", summary, [], test_file)
