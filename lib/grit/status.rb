module Grit
  
  class Status
    include Enumerable
    
    @base = nil
    @files = nil
    
    def initialize(base)
      @base = base
      construct_status
    end

    def added
      @files.select(&:added?)
    end

    def deleted
      @files.select(&:deleted?)
    end

    def modified
      @files.select(&:modified?)
    end

    def untracked
      @files.select(&:untracked?)
    end

    def staged_changes
      @files.select(&:changes_staged?)
    end

    def unstaged_changes
      @files.select(&:changes_unstaged?)
    end
    
    # enumerable method

    def [](file)
      @status[file]
    end

    def each(&block)
      @files.each(&block)
    end
    
    class StatusFile
      attr_accessor :path, :status, :stage
      attr_accessor :mode_index, :mode_repo
      attr_accessor :sha_index, :sha_repo
      
      @base = nil
      
      def initialize(base, hash)
        @base = base
        @path = hash[:path]
        @status = {'A' => :added, 'D' => :deleted, 'M' => :modified, 'U' => :untracked}[hash[:status]]
        @stage = hash[:stage]
        @mode_index = hash[:mode_index]
        @mode_repo = hash[:mode_repo]
        @sha_index = hash[:sha_index] =~ /^[0]*$/ ? nil : hash[:sha_index]
        @sha_repo = hash[:sha_repo] =~ /^[0]*$/ ? nil : hash[:sha_repo]
        @staged = hash[:staged]
      end

      def blob(type = nil)
        type = (changes_unstaged? ? :file : :index) unless type

        case type
        when :file
          file_path = File.join(@base.working_dir, path)
          File.read(file_path) if File.exist?(file_path)
        when :index
          @base.blob(sha_index) if sha_index
        when :repo
          @base.blob(sha_repo) if sha_repo
        end
      end

      def diff
        unless untracked?
          return @diff if @diff

          diff = @base.diff(nil, nil, path, :cached => changes_staged?)
          @diff = Diff.list_from_string(@base, diff).first
        end
      end

      def added?
        status == :added
      end

      def deleted?
        status == :deleted
      end

      def modified?
        status == :modified
      end

      def untracked?
        status == :untracked
      end

      def changed?
        !status.nil?
      end

      def changes_staged?
        changed? && @staged
      end

      def changes_unstaged?
        changed? && !@staged
      end
    end
    
    private
    
      def construct_status
        @status = {}
        ls_files.each do |file, data|
          add_file(file, data)
        end

        # find untracked files
        untracked_files.each do |file|
          add_file(file, {:path => file, :status => 'U', :staged => false})
        end

        # find modified in tree
        diff_files.each do |file, data|
          # if a file shows up here it has not yet been staged
          # info: staged deleted files don't show up in diff-files
          data[:staged] = false

          add_file(file, data)
        end

        # find added but not committed - new files
        diff_index('HEAD').each do |file, data|
          # the file has been staged
          # if the file has a index SHA or is marked as deleted
          # info: staged deleted files have no index SHA
          if (data[:sha_index] !~ /^[0]*$/ || data[:status] == 'D') ||
              (@status[file].last[:sha_repo] != data[:sha_repo])
            data[:staged] = true
          end

          add_file(file, data) if !(@status[file] && @status[file].last[:status] == 'D')
        end

        @status.each do |file, data_array|
          if data_array.size > 1
            @status[file] = data_array.map{ |data| StatusFile.new(@base, data) }
          else
            @status[file] = StatusFile.new(@base, data_array.first)
          end
        end
        @files = @status.values.flatten
      end

      def add_file(file, data)
        if @status[file]
          last_data = @status[file].last
          if !last_data[:status] || data[:staged].nil?
            @status[file][-1] =  data.merge!(last_data)
          else
            @status[file] << data
          end
        else
          @status[file] = [data]
        end
      end

      # compares the index and the working directory
      def diff_files
        hsh = {}
        @base.git.diff_files.split("\n").each do |line|
          (info, file) = line.split("\t")
          (mode_src, mode_dest, sha_src, sha_dest, status) = info.split
          hsh[file] = {:path => file, :mode_repo => mode_src.to_s[1, 7], :mode_index => mode_dest,
                        :sha_repo => sha_src, :sha_index => sha_dest, :status => status}
        end
        hsh
      end

      # compares the index and the repository
      def diff_index(treeish)
        hsh = {}
        @base.git.diff_index({}, treeish).split("\n").each do |line|
          (info, file) = line.split("\t")
          (mode_src, mode_dest, sha_src, sha_dest, status) = info.split
          hsh[file] = {:path => file, :mode_repo => mode_src.to_s[1, 7], :mode_index => mode_dest, 
                        :sha_repo => sha_src, :sha_index => sha_dest, :status => status}
        end
        hsh
      end

      def ls_files
        hsh = {}
        @base.git.ls_files({:stage => true}).split("\n").each do |line|
          (info, file) = line.split("\t")
          (mode, sha, stage) = info.split
          hsh[file] = {:path => file, :mode_index => mode, :sha_index => sha, :stage => stage}
        end
        hsh
      end

      def untracked_files
        other_files = @base.git.ls_files({:others => true}).split("\n")
        other_files - ignored_files
      end

      def ignored_files
        @base.git.ls_files({:others => true, :ignored => true, :exclude_standard => true}).split("\n")
      end
  end
  
end