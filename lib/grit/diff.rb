module Grit
  
  class Diff
    attr_reader :a_path, :b_path
    attr_reader :a_sha,  :b_sha
    attr_reader :a_blob, :b_blob
    attr_reader :a_mode, :b_mode
    attr_reader :new_file, :deleted_file
    attr_reader :diff
    
    def initialize(repo, a_path, b_path, a_sha, b_sha, a_mode, b_mode, new_file, deleted_file, diff)
      @repo = repo
      @a_path = a_path
      @b_path = b_path
      @a_sha  = a_sha =~ /^0*$/ ? nil : a_sha
      @b_sha  = b_sha =~ /^0*$/ ? nil : b_sha
      @a_blob = @a_sha.nil? ? nil : Blob.create(repo, :id => @a_sha)
      @b_blob = @b_sha.nil? ? nil : Blob.create(repo, :id => @b_sha)
      @a_mode = a_mode
      @b_mode = b_mode
      @new_file = new_file || @a_blob.nil?
      @deleted_file = deleted_file || @b_blob.nil?
      @diff = diff
    end
    
    def self.list_from_string(repo, text)
      lines = text.split("\n", -1)
      
      diffs = []
      
      while !lines.empty?
        m, a_path, b_path = *lines.shift.match(%r{^diff --git a/(.+?) b/(.+)$})
        
        if lines.first =~ /^old mode/
          m, a_mode = *lines.shift.match(/^old mode (\d+)/)
          m, b_mode = *lines.shift.match(/^new mode (\d+)/)
        end
        
        if lines.empty? || lines.first =~ /^diff --git/
          diffs << Diff.new(repo, a_path, b_path, nil, nil, a_mode, b_mode, false, false, nil)
          next
        end
        
        new_file = false
        deleted_file = false
        
        if lines.first =~ /^new file/
          m, b_mode = lines.shift.match(/^new file mode (.+)$/)
          a_mode = nil
          new_file = true
        elsif lines.first =~ /^deleted file/
          m, a_mode = lines.shift.match(/^deleted file mode (.+)$/)
          b_mode = nil
          deleted_file = true
        end
        
        m, a_sha, b_sha, b_mode = *lines.shift.match(%r{^index ([0-9A-Fa-f]+)\.\.([0-9A-Fa-f]+) ?(.+)?$})
        b_mode.strip! if b_mode
        
        diff_lines = []
        while lines.first && lines.first !~ /^diff/
          diff_lines << lines.shift
        end
        diff = diff_lines.join("\n")
        diff = nil if diff.empty?
        
        diffs << Diff.new(repo, a_path, b_path, a_sha, b_sha, a_mode, b_mode, new_file, deleted_file, diff)
      end
      
      diffs
    end

    # Tells you the number of deleted lines in the diff.
    def deletions
      # -1 for the line starting in ---
      self.diff.split("\n").count { |line| line.start_with?('-') } -1
    end

    # Tells you the number of inserted lines in the diff.
    def insertions
      # -1 for the line starting in +++
      self.diff.split("\n").count { |line| line.start_with?('+') } -1
    end
  end # Diff
  
end # Grit
