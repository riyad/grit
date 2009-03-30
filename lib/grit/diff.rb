    attr_reader :a_blob, :b_blob
    def initialize(repo, a_path, b_path, a_blob, b_blob, a_mode, b_mode, new_file, deleted_file, diff)
      @a_blob = a_blob =~ /^0{40}$/ ? nil : Blob.create(repo, :id => a_blob)
      @b_blob = b_blob =~ /^0{40}$/ ? nil : Blob.create(repo, :id => b_blob)
        m, a_blob, b_blob, b_mode = *lines.shift.match(%r{^index ([0-9A-Fa-f]+)\.\.([0-9A-Fa-f]+) ?(.+)?$})
        diffs << Diff.new(repo, a_path, b_path, a_blob, b_blob, a_mode, b_mode, new_file, deleted_file, diff)