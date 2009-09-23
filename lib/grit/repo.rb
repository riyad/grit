module Grit
  
  class Repo
    DAEMON_EXPORT_FILE = 'git-daemon-export-ok'
    
    # The path of the git repo as a String
    attr_accessor :path
    attr_accessor :working_dir
    attr_reader :bare
    
    # The git command line interface object
    attr_accessor :git
    
    # Create a new Repo instance
    #   +path+ is the path to either the root git directory or the bare git repo
    #   +options+ :is_bare force to load a bare repo
    #
    # Examples
    #   g = Repo.new("/Users/tom/dev/grit")
    #   g = Repo.new("/Users/tom/public/grit.git")
    #
    # Returns Grit::Repo
    def initialize(path, options = {})
      epath = File.expand_path(path)
      
      if File.exist?(File.join(epath, '.git'))
        self.working_dir = epath
        self.path = File.join(epath, '.git')
        @bare = false
      elsif File.exist?(epath) && (epath =~ /\.git$/ || options[:is_bare])
        self.path = epath
        @bare = true
      elsif File.exist?(epath)
        raise InvalidGitRepositoryError.new(epath)
      else
        raise NoSuchPathError.new(epath)
      end
      
      self.git = Git.new(self.path)
    end

    # Clones _their_repo_ into _my_repo_.
    # Note that the _my_repo_ location may not exists before.
    #
    # _options_ may include:
    # [<tt>:bare => true</tt>] if it should only do a bare clone
    #
    # Returns the Grit::Repo of the cloned repository.
    #
    # === Examples
    #   Repo.clone('git://github.com/mojombo/grit.git', '~/projects/my_grit_clone')
    #   => #<Grit::Repo "~/projects/my_grit_clone/.git">
    #
    #   Repo.clone('git://github.com/mojombo/grit.git', '~/projects/my_grit_clone.git', :bare => true)
    #   => #<Grit::Repo "~/projects/my_grit_clone.git">
    def self.clone(their_repo, my_repo, options = {})
      repo_path = File.expand_path(my_repo)
      bare_repo_path = options[:bare] ? repo_path : File.join(repo_path, '.git')

      Grit::Git.new(bare_repo_path).clone({:bare => true}, their_repo, bare_repo_path)
      repo = Grit::Repo.new(repo_path, :is_bare => options[:bare])

      repo.git.checkout({}, 'HEAD') unless options[:bare]

      repo
    end

    # Checks whether a given path contains a git repo.
    #
    # _options_ may include:
    # [<tt>:bare => true</tt>] if the dir contains a bare repo
    #
    # Returns +true+ if _path_ contains a git repo otherwise +false+.
    #
    # === Examples
    #   Repo.contains_repository?('~/projects/foo')
    #   => true
    #
    #   Repo.contains_repository?('~/projects/foo', :bare => true)
    #   => false
    #
    #   Repo.contains_repository?('~/projects/foo/.git')
    #   => true
    #
    #   Repo.contains_repository?('~/projects/bar.git')
    #   => true
    def self.contains_repository?(path, options = {})
      repo_path =  File.expand_path(path)

      unless options[:bare]
        dot_git_path = File.join(repo_path, '.git')
        bare_repo_path = dot_git_path if File.directory?(dot_git_path)
      end

      bare_repo_path ||= repo_path

      is_dir_in_bare_git_repo = {'branches' => true, 'config' => false, 'index' => false, 'objects' => true, 'refs' => true}

      File.directory?(bare_repo_path) && # is dir
        (is_dir_in_bare_git_repo.keys - Dir.entries(bare_repo_path)).size == 0 && # has all the wantend entries
        is_dir_in_bare_git_repo.keys.all? { |entry| File.directory?(File.join(bare_repo_path, entry)) == is_dir_in_bare_git_repo[entry]}
    end

    # Creates a fresh repository in _my_repo_.
    # Note that the _my_repo_ location may not exists before.
    #
    # _options_ may include:
    # [<tt>:bare => true</tt>] if it should do a bare init
    #
    # Returns the Grit::Repo of the new repository.
    #
    # === Examples
    #   Repo.init('~/projects/foo')
    #   => #<Grit::Repo "~/projects/foo/.git">
    #
    #   Repo.init('~/projects/bar.git', :bare => true)
    #   => #<Grit::Repo "~/projects/bar.git">
    def self.init(my_repo, options = {})
      repo_path = File.expand_path(my_repo)
      bare_repo_path = options[:bare] ? repo_path : File.join(repo_path, '.git')

      Git.new(bare_repo_path).init(options)

      Grit::Repo.new(repo_path, :is_bare => options[:bare])
    end
    
    # The project's description. Taken verbatim from GIT_REPO/description
    #
    # Returns String
    def description
      File.open(File.join(self.path, 'description')).read.chomp
    end

    def blame(file, commit = nil)
      Blame.new(self, file, commit)
    end

    
    # An array of Head objects representing the branch heads in
    # this repo
    #
    # Returns Grit::Head[] (baked)
    def heads
      Head.find_all(self)
    end
    
    alias_method :branches, :heads

    def get_head(head_name)
      heads.find { |h| h.name == head_name }
    end
    
    def is_head?(head_name)
      get_head(head_name)
    end
    
    # Object reprsenting the current repo head.
    #
    # Returns Grit::Head (baked)
    def head
      Head.current(self)
    end


    # Commits current index
    #
    # Returns true/false if commit worked
    def commit_index(message)
      self.git.commit({}, '-m', message)
    end

    # Commits all tracked and modified files
    #
    # Returns true/false if commit worked
    def commit_all(message)
      self.git.commit({}, '-a', '-m', message)
    end

    # Adds files to the index
    def add(*files)
      self.git.add({}, *files.flatten)
    end

    # Remove files from the index
    def remove(*files)
      self.git.rm({}, *files.flatten)
    end

    # Stages _files_ to be included in the next commit (see #commit_index).
    #
    # === Examples
    #   repo.stage_files('README', 'foo', 'bar/')
    def stage_files(*files)
      self.git.add({}, *files)
    end

    # Unstages (staged) _files_ to *not* be included in the next commit (see #commit_index).
    #
    # === Examples
    #   repo.unstage_files('README', 'bar/')
    def unstage_files(*files)
      commits = heads.inject(0) { |sum, head| sum + commit_count(head.commit.to_s) }

      if commits == 0
        self.git.rm({:cached => true}, *files)
      else
        files = ['HEAD', '--'] + files
        self.git.reset({}, *files)
      end
    end
    

    def blame_tree(commit, path = nil)
      commit_array = self.git.blame_tree(commit, path)
      
      final_array = {}
      commit_array.each do |file, sha|
        final_array[file] = commit(sha)
      end
      final_array
    end
    
    def status
      Status.new(self)
    end


    # An array of Tag objects that are available in this repo
    #
    # Returns Grit::Tag[] (baked)
    def tags
      Tag.find_all(self)
    end
    
    # An array of Remote objects representing the remote branches in
    # this repo
    #
    # Returns Grit::Remote[] (baked)
    def remotes
      Remote.find_all(self)
    end

    # An array of Ref objects representing the refs in
    # this repo
    #
    # Returns Grit::Ref[] (baked)
    def refs
      [ Head.find_all(self), Tag.find_all(self), Remote.find_all(self) ].flatten
    end

    def commit_stats(start = 'master', max_count = 10, skip = 0)
      options = {:max_count => max_count,
                 :skip => skip}
      
      CommitStats.find_all(self, start, options)
    end
    
    # An array of Commit objects representing the history of a given ref/commit
    #   +start+ is the branch/commit name (default 'master')
    #   +max_count+ is the maximum number of commits to return (default 10, use +false+ for all)
    #   +skip+ is the number of commits to skip (default 0)
    #
    # Returns Grit::Commit[] (baked)
    def commits(start = 'master', max_count = 10, skip = 0)
      options = {:max_count => max_count,
                 :skip => skip}
      
      Commit.find_all(self, start, options)
    end
    
    # The Commits objects that are reachable via +to+ but not via +from+
    # Commits are returned in chronological order.
    #   +from+ is the branch/commit name of the younger item
    #   +to+ is the branch/commit name of the older item
    #
    # Returns Grit::Commit[] (baked)
    def commits_between(from, to)
      Commit.find_all(self, "#{from}..#{to}").reverse
    end
    
    # The Commits objects that are newer than the specified date.
    # Commits are returned in chronological order.
    #   +start+ is the branch/commit name (default 'master')
    #   +since+ is a string represeting a date/time
    #   +extra_options+ is a hash of extra options
    #
    # Returns Grit::Commit[] (baked)
    def commits_since(start = 'master', since = '1970-01-01', extra_options = {})
      options = {:since => since}.merge(extra_options)
      
      Commit.find_all(self, start, options)
    end
    
    # The number of commits reachable by the given branch/commit
    #   +start+ is the branch/commit name (default 'master')
    #
    # Returns Integer
    def commit_count(start = 'master')
      Commit.count(self, start)
    end
    
    # The Commit object for the specified id
    #   +id+ is the SHA1 identifier of the commit
    #
    # Returns Grit::Commit (baked)
    def commit(id)
      options = {:max_count => 1}
      
      Commit.find_all(self, id, options).first
    end
    
    # Returns a list of commits that is in +other_repo+ but not in self
    #
    # Returns Grit::Commit[]
    def commit_deltas_from(other_repo, ref = "master", other_ref = "master")
      # TODO: we should be able to figure out the branch point, rather than
      # rev-list'ing the whole thing
      repo_refs       = self.git.rev_list({}, ref).strip.split("\n")
      other_repo_refs = other_repo.git.rev_list({}, other_ref).strip.split("\n")
      
      (other_repo_refs - repo_refs).map do |ref|
        Commit.find_all(other_repo, ref, {:max_count => 1}).first
      end
    end
    
    # The Tree object for the given treeish reference
    #   +treeish+ is the reference (default 'master')
    #   +paths+ is an optional Array of directory paths to restrict the tree (deafult [])
    #
    # Examples
    #   repo.tree('master', ['lib/'])
    #
    # Returns Grit::Tree (baked)
    def tree(treeish = 'master', paths = [])
      Tree.construct(self, treeish, paths)
    end
    
    # The Blob object for the given id
    #   +id+ is the SHA1 id of the blob
    #
    # Returns Grit::Blob (unbaked)
    def blob(id)
      Blob.create(self, :id => id)
    end

    # The commit log for a treeish
    #
    # Returns Grit::Commit[]
    def log(commit = 'master', path = nil, options = {})
      default_options = {:pretty => "raw"}
      actual_options  = default_options.merge(options)
      arg = path ? [commit, '--', path] : [commit]
      commits = self.git.log(actual_options, *arg)
      Commit.list_from_string(self, commits)
    end
    
    # The diff from commit +a+ to commit +b+, optionally restricted to the given file(s)
    #   +a+ is the base commit
    #   +b+ is the other commit
    #   +paths+ is an optional list of file paths on which to restrict the diff
    def diff(a, b, *paths)
      self.git.diff({}, a, b, '--', *paths)
    end
    
    # The commit diff for the given commit
    #   +commit+ is the commit name/id
    #
    # Returns Grit::Diff[]
    def commit_diff(commit)
      Commit.diff(self, commit)
    end
    
    # Fork a bare git repository from this repo
    #   +path+ is the full path of the new repo (traditionally ends with /<name>.git)
    #   +options+ is any additional options to the git clone command (:bare and :shared are true by default)
    #
    # Returns Grit::Repo (the newly forked repo)
    def fork_bare(path, options = {})
      default_options = {:bare => true, :shared => true}
      real_options = default_options.merge(options)
      self.git.clone(real_options, self.path, path)
      Repo.new(path)
    end
    
    # Archive the given treeish
    #   +treeish+ is the treeish name/id (default 'master')
    #   +prefix+ is the optional prefix
    #
    # Examples
    #   repo.archive_tar
    #   # => <String containing tar archive>
    #
    #   repo.archive_tar('a87ff14')
    #   # => <String containing tar archive for commit a87ff14>
    #
    #   repo.archive_tar('master', 'myproject/')
    #   # => <String containing tar archive and prefixed with 'myproject/'>
    #
    # Returns String (containing tar archive)
    def archive_tar(treeish = 'master', prefix = nil)
      options = {}
      options[:prefix] = prefix if prefix
      self.git.archive(options, treeish)
    end
    
    # Archive and gzip the given treeish
    #   +treeish+ is the treeish name/id (default 'master')
    #   +prefix+ is the optional prefix
    #
    # Examples
    #   repo.archive_tar_gz
    #   # => <String containing tar.gz archive>
    #
    #   repo.archive_tar_gz('a87ff14')
    #   # => <String containing tar.gz archive for commit a87ff14>
    #
    #   repo.archive_tar_gz('master', 'myproject/')
    #   # => <String containing tar.gz archive and prefixed with 'myproject/'>
    #
    # Returns String (containing tar.gz archive)
    def archive_tar_gz(treeish = 'master', prefix = nil)
      options = {}
      options[:prefix] = prefix if prefix
      self.git.archive(options, treeish, "| gzip")
    end

    # Write an archive directly to a file
    #   +treeish+ is the treeish name/id (default 'master')
    #   +prefix+ is the optional prefix (default nil)
    #   +filename+ is the name of the file (default 'archive.tar.gz')
    #   +format+ is the optional format (default nil)
    #   +pipe+ is the command to run the output through (default 'gzip')
    #
    # Returns nothing
    def archive_to_file(treeish = 'master', prefix = nil, filename = 'archive.tar.gz', format = nil, pipe = "gzip")
      options = {}
      options[:prefix] = prefix if prefix
      options[:format] = format if format
      self.git.archive(options, treeish, "| #{pipe} > #{filename}")
    end

    # Enable git-daemon serving of this repository by writing the
    # git-daemon-export-ok file to its git directory
    #
    # Returns nothing
    def enable_daemon_serve
      FileUtils.touch(File.join(self.path, DAEMON_EXPORT_FILE))
    end
    
    # Disable git-daemon serving of this repository by ensuring there is no
    # git-daemon-export-ok file in its git directory
    #
    # Returns nothing
    def disable_daemon_serve
      FileUtils.rm_f(File.join(self.path, DAEMON_EXPORT_FILE))
    end
    
    def gc_auto
      self.git.gc({:auto => true})
    end
    
    # The list of alternates for this repo
    #
    # Returns Array[String] (pathnames of alternates)
    def alternates
      alternates_path = File.join(self.path, *%w{objects info alternates})
      
      if File.exist?(alternates_path)
        File.read(alternates_path).strip.split("\n")
      else
        []
      end
    end
    
    # Sets the alternates
    #   +alts+ is the Array of String paths representing the alternates
    #
    # Returns nothing
    def alternates=(alts)
      alts.each do |alt|
        unless File.exist?(alt)
          raise "Could not set alternates. Alternate path #{alt} must exist"
        end
      end
      
      if alts.empty?
        File.open(File.join(self.path, *%w{objects info alternates}), 'w') do |f|
          f.write ''
        end
      else
        File.open(File.join(self.path, *%w{objects info alternates}), 'w') do |f|
          f.write alts.join("\n")
        end
      end
    end
    
    def config
      @config ||= Config.new(self)
    end
    
    def index
      Index.new(self)
    end
    
    def update_ref(head, commit_sha)
      return nil if !commit_sha || (commit_sha.size != 40)
   
      ref_heads = File.join(self.path, 'refs', 'heads')
      FileUtils.mkdir_p(ref_heads)
      File.open(File.join(ref_heads, head), 'w') do |f|
        f.write(commit_sha)
      end
      commit_sha

    end
    
    # Pretty object inspection
    def inspect
      %Q{#<Grit::Repo "#{@path}">}
    end
  end # Repo
  
end # Grit
