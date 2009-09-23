require File.dirname(__FILE__) + '/helper'

class TestStatus < Test::Unit::TestCase
  def temp_repo
    filename = "git_test#{Time.now.to_i.to_s}#{rand(300).to_s.rjust(3, '0')}"
    tmp_path = File.join("/tmp/", filename)

    repo = Grit::Repo.init(tmp_path)
    repo.commit_index('Empty inital commit.', :allow_empty => true)

    repo
  end

  def in_temp_repo
    repo = temp_repo
    yield repo
    FileUtils.rm_r(repo.working_dir)
  end

  def new_file(name, contents)
    File.open(name, 'w') do |f|
      f.print contents
    end
  end

  def temp_repo_with_new_file
    return @temp_repo_with_new_file if @temp_repo_with_new_file

    repo = temp_repo
    Dir.chdir repo.working_dir do # for new_file() to work correctly
      new_file('untracked.txt', "foo\nbar\nbaz\n")
    end
    @temp_repo_with_new_file = repo
  end

  def temp_repo_with_newly_added_file
    return @temp_repo_with_newly_added_file if @temp_repo_with_newly_added_file

    repo = temp_repo
    Dir.chdir repo.working_dir do # for new_file() to work correctly
      new_file('newly_added.txt', "foo\nbar\nbaz\n")
      repo.stage_files('newly_added.txt')
    end
    @temp_repo_with_newly_added_file = repo
  end

  def temp_repo_with_modified_file
    return @temp_repo_with_modified_file if @temp_repo_with_modified_file

    repo = temp_repo
    Dir.chdir repo.working_dir do # for new_file() to work correctly
      new_file('modified.txt', "foo\nbar")
      repo.stage_files('modified.txt')
      repo.commit_index("Committed file to be modified.")
      new_file('modified.txt', "foo\nbar\nbaz\n")
    end
    @temp_repo_with_modified_file = repo
  end

  # tests

  def test_invocations
    Git.any_instance.expects(:ls_files).with(:stage => true).returns('')
    Git.any_instance.expects(:ls_files).with(:others => true).returns('')
    Git.any_instance.expects(:ls_files).with(:others => true, :ignored => true, :exclude_standard => true).returns('')
    Git.any_instance.expects(:diff_index).with({}, 'HEAD').returns('')
    Git.any_instance.expects(:diff_files).with().returns('')

    in_temp_repo do |r|
      assert_not_nil(r.status)
    end
  end

  def test_new_file_has_status
    r = temp_repo_with_new_file

    assert_not_nil(r.status['untracked.txt'])
  end

  def test_new_file_is_untracked
    r = temp_repo_with_new_file
    s = r.status['untracked.txt']

    assert(s.untracked?)
    assert_equal(:untracked, s.status)
  end

  def test_new_file_is_unstaged
    r = temp_repo_with_new_file
    s = r.status['untracked.txt']

    assert(!s.changes_staged?)
    assert(s.changes_unstaged?)
  end

  def test_new_file_default_blob_is_file_blob
    r = temp_repo_with_new_file

    assert_equal(r.status['untracked.txt'].blob(:file), r.status['untracked.txt'].blob)
  end

  def test_new_file_file_blob_is_correct
    r = temp_repo_with_new_file

    assert_equal("foo\nbar\nbaz\n", r.status['untracked.txt'].blob(:file))
  end

  def test_new_file_index_blob_is_empty
    r = temp_repo_with_new_file

    assert_nil(r.status['untracked.txt'].blob(:index))
  end

  def test_new_file_repo_blob_is_empty
    r = temp_repo_with_new_file

    assert_nil(r.status['untracked.txt'].blob(:repo))
  end

  def test_new_file_has_no_diff
    r = temp_repo_with_new_file
    s = r.status['untracked.txt']

    assert_nil(s.diff)
  end

  def test_newly_added_file_has_status
    r = temp_repo_with_newly_added_file

    assert_not_nil(r.status['newly_added.txt'])
  end

  def test_newly_added_file_is_added
    r = temp_repo_with_newly_added_file

    s = r.status['newly_added.txt']

    assert(s.added?)
    assert_equal(:added, s.status)
  end

  def test_newly_added_file_is_staged
    r = temp_repo_with_newly_added_file

    s = r.status['newly_added.txt']

    assert(s.changes_staged?)
    assert(!s.changes_unstaged?)
  end

  def test_newly_added_file_default_blob_is_index_blob
    r = temp_repo_with_newly_added_file

    assert_equal(r.status['newly_added.txt'].blob(:index).data, r.status['newly_added.txt'].blob.data)
  end

  def test_newly_added_file_file_blob_is_correct
    r = temp_repo_with_newly_added_file

    assert_equal("foo\nbar\nbaz\n", r.status['newly_added.txt'].blob(:file))
  end

  def test_newly_added_file_index_blob_is_correct
    r = temp_repo_with_newly_added_file

    assert_equal("foo\nbar\nbaz\n", r.status['newly_added.txt'].blob(:index).data)
  end

  def test_newly_added_file_repo_blob_is_empty
    r = temp_repo_with_newly_added_file

    assert_nil(r.status['newly_added.txt'].blob(:repo))
  end

  def test_newly_added_file_diff_is_correct
    r = temp_repo_with_newly_added_file

    d = r.status['newly_added.txt'].diff

    assert_not_nil(d)
    assert_equal('newly_added.txt', d.a_path)
    assert_equal('newly_added.txt', d.b_path)
    assert(d.new_file)
    assert(!d.deleted_file)
    assert_nil(d.a_sha)
    assert_equal('86e041d', d.b_sha)
    assert_equal("--- /dev/null\n+++ b/newly_added.txt\n@@ -0,0 +1,3 @@\n+foo\n+bar\n+baz\n", d.diff)
  end

  def test_modified_file_has_status
    r = temp_repo_with_modified_file

    assert_not_nil(r.status['modified.txt'])
  end

  def test_modified_file_is_modified
    r = temp_repo_with_modified_file
    s = r.status['modified.txt']

    assert(s.modified?)
    assert_equal(:modified, s.status)
  end

  def test_modified_file_is_unstaged
    r = temp_repo_with_modified_file
    s = r.status['modified.txt']

    assert(!s.changes_staged?)
    assert(s.changes_unstaged?)
  end

  def test_modified_file_default_blob_is_file_blob
    r = temp_repo_with_modified_file

    assert_equal(r.status['modified.txt'].blob(:file), r.status['modified.txt'].blob)
  end

  def test_modified_file_file_blob_is_correct
    r = temp_repo_with_modified_file

    assert_equal("foo\nbar\nbaz\n", r.status['modified.txt'].blob(:file))
  end

  def test_modified_file_index_blob_is_correct
    r = temp_repo_with_modified_file

    assert_equal("foo\nbar", r.status['modified.txt'].blob(:index).data)
  end

  def test_modified_file_repo_blob_is_correct
    r = temp_repo_with_modified_file

    assert_equal("foo\nbar", r.status['modified.txt'].blob(:repo).data)
  end

  def test_modified_file_uncached_diff_is_correct
    r = temp_repo_with_modified_file

    d = r.status['modified.txt'].diff

    assert_not_nil(d)
    assert_equal('modified.txt', d.a_path)
    assert_equal('modified.txt', d.b_path)
    assert(!d.new_file)
    assert(!d.deleted_file)
    assert_equal('a907ec3', d.a_sha)
    assert_equal('86e041d', d.b_sha)
    assert_equal("--- a/modified.txt\n+++ b/modified.txt\n@@ -1,2 +1,3 @@\n foo\n-bar\n\\ No newline at end of file\n+bar\n+baz\n", d.diff)
  end

  def test_updated_file_has_status
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      assert_not_nil(g.status['updated.txt'])
    end
  end

  def test_updated_file_is_modified
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      s = g.status['updated.txt']

      assert(s.modified?)
      assert_equal(:modified, s.status)
    end
  end

  def test_updated_file_is_staged
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      s = g.status['updated.txt']

      assert(s.changes_staged?)
      assert(!s.changes_unstaged?)
    end
  end

  def test_updated_file_default_blob_is_index_blob
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      assert_equal(g.status['updated.txt'].blob(:index).data, g.status['updated.txt'].blob.data)
    end
  end

  def test_updated_file_file_blob_is_correct
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      assert_equal("foo\nbar\nbaz\n", g.status['updated.txt'].blob(:file))
    end
  end

  def test_updated_file_index_blob_is_correct
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      assert_equal("foo\nbar\nbaz\n", g.status['updated.txt'].blob(:index).data)
    end
  end

  def test_updated_file_repo_blob_is_correct
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      assert_equal("foo\nbar", g.status['updated.txt'].blob(:repo).data)
    end
  end

  def test_updated_file_diff_is_correct
    in_temp_repo do |g|
      new_file('updated.txt', "foo\nbar")
      g.stage_files('updated.txt')
      g.commit_index("Committed file to be modified.")
      new_file('updated.txt', "foo\nbar\nbaz\n")
      g.stage_files('updated.txt')

      d = g.status['updated.txt'].diff

      assert_not_nil(d)
      assert_equal('updated.txt', d.a_path)
      assert_equal('updated.txt', d.b_path)
      assert(!d.new_file)
      assert(!d.deleted_file)
      assert_equal('a907ec3', d.a_sha)
      assert_equal('86e041d', d.b_sha)
      assert_equal("--- a/updated.txt\n+++ b/updated.txt\n@@ -1,2 +1,3 @@\n foo\n-bar\n\\ No newline at end of file\n+bar\n+baz\n", d.diff)
    end
  end

  def test_removed_file_has_status
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      assert_not_nil(g.status['removed.txt'])
    end
  end

  def test_removed_file_is_deleted
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      s = g.status['removed.txt']

      assert(s.deleted?)
      assert_equal(:deleted, s.status)
    end
  end

  def test_removed_file_is_staged
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      s = g.status['removed.txt']

      assert(s.changes_staged?)
      assert(!s.changes_unstaged?)
    end
  end

  def test_removed_file_default_blob_is_index_blob
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      assert_equal(g.status['removed.txt'].blob(:index), g.status['removed.txt'].blob)
    end
  end

  def test_removed_file_file_blob_is_empty
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      assert_nil(g.status['removed.txt'].blob(:file))
    end
  end

  def test_removed_file_index_blob_is_empty
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      assert_nil(g.status['removed.txt'].blob(:index))
    end
  end

  def test_removed_file_repo_blob_is_correct
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      assert_equal("foo\nbar\nbaz\n", g.status['removed.txt'].blob(:repo).data)
    end
  end

  def test_removed_file_diff_is_correct
    in_temp_repo do |g|
      new_file('removed.txt', "foo\nbar\nbaz\n")
      g.stage_files('removed.txt')
      g.commit_index("Added file to be deleted.")
      g.remove('removed.txt') # also stages the changes

      d = g.status['removed.txt'].diff

      assert_not_nil(d)
      assert_equal('removed.txt', d.a_path)
      assert_equal('removed.txt', d.b_path)
      assert(!d.new_file)
      assert(d.deleted_file)
      assert_equal('86e041d', d.a_sha)
      assert_nil(d.b_sha)
      assert_equal("--- a/removed.txt\n+++ /dev/null\n@@ -1,3 +0,0 @@\n-foo\n-bar\n-baz\n", d.diff)
    end
  end

  def test_deleted_file_has_status
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      assert_not_nil(g.status['deleted.txt'])
    end
  end

  def test_deleted_file_is_deleted
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      s = g.status['deleted.txt']

      assert(s.deleted?)
      assert_equal(:deleted, s.status)
    end
  end

  def test_deleted_file_is_unstaged
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      s = g.status['deleted.txt']

      assert(!s.changes_staged?)
      assert(s.changes_unstaged?)
    end
  end

  def test_deleted_file_default_blob_is_file_blob
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      assert_equal(g.status['deleted.txt'].blob(:file), g.status['deleted.txt'].blob)
    end
  end

  def test_deleted_file_file_blob_is_empty
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      assert_nil(g.status['deleted.txt'].blob(:file))
    end
  end

  def test_deleted_file_index_blob_is_correct
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      assert_equal("foo\nbar\nbaz\n", g.status['deleted.txt'].blob(:index).data)
    end
  end

  def test_deleted_file_repo_blob_is_correct
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      assert_equal("foo\nbar\nbaz\n", g.status['deleted.txt'].blob(:repo).data)
    end
  end

  def test_deleted_file_diff_is_correct
    in_temp_repo do |g|
      new_file('deleted.txt', "foo\nbar\nbaz\n")
      g.stage_files('deleted.txt')
      g.commit_index("Added file to be deleted.")
      FileUtils.rm('deleted.txt')

      d = g.status['deleted.txt'].diff

      assert_not_nil(d)
      assert_equal('deleted.txt', d.a_path)
      assert_equal('deleted.txt', d.b_path)
      assert(!d.new_file)
      assert(d.deleted_file)
      assert_equal('86e041d', d.a_sha)
      assert_nil(d.b_sha)
      assert_equal("--- a/deleted.txt\n+++ /dev/null\n@@ -1,3 +0,0 @@\n-foo\n-bar\n-baz\n", d.diff)
    end
  end

  def test_remodified_file_has_status
    in_temp_repo do |g|
      new_file('remodified.txt', "foo")
      g.stage_files('remodified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('remodified.txt', "foo\nbar\n")
      g.stage_files('remodified.txt')
      new_file('remodified.txt', "foo\nbar\nbaz\n")

      s = g.status['remodified.txt']

      assert_not_nil(s)
      assert_kind_of(Array, s)
      assert_equal(2, s.size)
    end
  end

  def test_remodified_file_is_modified
    in_temp_repo do |g|
      new_file('remodified.txt', "foo")
      g.stage_files('remodified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('remodified.txt', "foo\nbar\n")
      g.stage_files('remodified.txt')
      new_file('remodified.txt', "foo\nbar\nbaz\n")

      s = g.status['remodified.txt']

      assert(s.all?(&:modified?))
    end
  end

  def test_remodified_file_is_staged_and_unstaged
    in_temp_repo do |g|
      new_file('remodified.txt', "foo")
      g.stage_files('remodified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('remodified.txt', "foo\nbar\n")
      g.stage_files('remodified.txt')
      new_file('remodified.txt', "foo\nbar\nbaz\n")

      s = g.status['remodified.txt']

      assert(s.any?(&:changes_staged?))
      assert(s.any?(&:changes_unstaged?))
    end
  end

  def test_unstaged_remodified_file_blobs_are_correct
    in_temp_repo do |g|
      new_file('remodified.txt', "foo")
      g.stage_files('remodified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('remodified.txt', "foo\nbar\n")
      g.stage_files('remodified.txt')
      new_file('remodified.txt', "foo\nbar\nbaz\n")

      s = g.status['remodified.txt'].select(&:changes_unstaged?).first

      assert_equal(s.blob(:file), s.blob)
      assert_equal("foo\nbar\nbaz\n", s.blob(:file))
      assert_equal("foo\nbar\n", s.blob(:index).data)
      assert_equal("foo\nbar\n", s.blob(:repo).data)
    end
  end

  def test_staged_remodified_file_blobs_are_correct
    in_temp_repo do |g|
      new_file('remodified.txt', "foo")
      g.stage_files('remodified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('remodified.txt', "foo\nbar\n")
      g.stage_files('remodified.txt')
      new_file('remodified.txt', "foo\nbar\nbaz\n")

      s = g.status['remodified.txt'].select(&:changes_staged?).first

      assert_equal(s.blob(:index), s.blob)
      assert_equal("foo\nbar\nbaz\n", s.blob(:file))
      assert_nil(s.blob(:index))
      assert_equal("foo", s.blob(:repo).data)
    end
  end

  def test_unstaged_remodified_file_diff_is_correct
    in_temp_repo do |g|
      new_file('remodified.txt', "foo")
      g.stage_files('remodified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('remodified.txt', "foo\nbar\n")
      g.stage_files('remodified.txt')
      new_file('remodified.txt', "foo\nbar\nbaz\n")

      s = g.status['remodified.txt'].select(&:changes_unstaged?).first
      d = s.diff

      assert_not_nil(d)
      assert_equal('remodified.txt', d.a_path)
      assert_equal('remodified.txt', d.b_path)
      assert(!d.new_file)
      assert(!d.deleted_file)
      assert_equal('3bd1f0e', d.a_sha)
      assert_equal('86e041d', d.b_sha)
      assert_equal("--- a/remodified.txt\n+++ b/remodified.txt\n@@ -1,2 +1,3 @@\n foo\n bar\n+baz\n", d.diff)
    end
  end

  def test_staged_remodified_file_diff_is_correct
    in_temp_repo do |g|
      new_file('remodified.txt', "foo")
      g.stage_files('remodified.txt')
      g.commit_index("Committed file to be modified.")
      new_file('remodified.txt', "foo\nbar\n")
      g.stage_files('remodified.txt')
      new_file('remodified.txt', "foo\nbar\nbaz\n")

      s = g.status['remodified.txt'].select(&:changes_staged?).first
      d = s.diff

      assert_not_nil(d)
      assert_equal('remodified.txt', d.a_path)
      assert_equal('remodified.txt', d.b_path)
      assert(!d.new_file)
      assert(!d.deleted_file)
      assert_equal('1910281', d.a_sha)
      assert_equal('3bd1f0e', d.b_sha)
      assert_equal("--- a/remodified.txt\n+++ b/remodified.txt\n@@ -1 +1,2 @@\n-foo\n\\ No newline at end of file\n+foo\n+bar\n", d.diff)
    end
  end

  def test_modified_added_file_has_status
    in_temp_repo do |g|
      new_file('modified_added.txt', "foo")
      g.stage_files('modified_added.txt')
      new_file('modified_added.txt', "foo\nbar\n")

      s = g.status['modified_added.txt']

      assert_not_nil(s)
      assert_kind_of(Array, s)
      assert_equal(2, s.size)
    end
  end

  def test_modified_added_file_is_added_and_modified
    in_temp_repo do |g|
      new_file('modified_added.txt', "foo")
      g.stage_files('modified_added.txt')
      new_file('modified_added.txt', "foo\nbar\n")

      s = g.status['modified_added.txt']

      assert(s.any?(&:added?))
      assert(s.any?(&:modified?))
    end
  end

  def test_modified_added_file_is_staged_and_unstaged
    in_temp_repo do |g|
      new_file('modified_added.txt', "foo")
      g.stage_files('modified_added.txt')
      new_file('modified_added.txt', "foo\nbar\n")

      s = g.status['modified_added.txt']

      assert(s.any?(&:changes_staged?))
      assert(s.any?(&:changes_unstaged?))
    end
  end

  def test_unstaged_modified_added_file_blobs_are_correct
    in_temp_repo do |g|
      new_file('modified_added.txt', "foo")
      g.stage_files('modified_added.txt')
      new_file('modified_added.txt', "foo\nbar\n")

      s = g.status['modified_added.txt'].select(&:changes_unstaged?).first

      assert_equal(s.blob(:file), s.blob)
      assert_equal("foo\nbar\n", s.blob(:file))
      assert_equal("foo", s.blob(:index).data)
      assert_equal("foo", s.blob(:repo).data)
    end
  end

  def test_staged_modified_added_file_blobs_are_correct
    in_temp_repo do |g|
      new_file('modified_added.txt', "foo")
      g.stage_files('modified_added.txt')
      new_file('modified_added.txt', "foo\nbar\n")

      s = g.status['modified_added.txt'].select(&:changes_staged?).first

      assert_equal(s.blob(:index), s.blob)
      assert_equal("foo\nbar\n", s.blob(:file))
      assert_nil(s.blob(:index))
      assert_nil(s.blob(:repo))
    end
  end

  def test_unstaged_modified_added_file_diff_is_correct
    in_temp_repo do |g|
      new_file('modified_added.txt', "foo")
      g.stage_files('modified_added.txt')
      new_file('modified_added.txt', "foo\nbar\n")

      s = g.status['modified_added.txt'].select(&:changes_unstaged?).first
      d = s.diff

      assert_not_nil(d)
      assert_equal('modified_added.txt', d.a_path)
      assert_equal('modified_added.txt', d.b_path)
      assert(!d.new_file)
      assert(!d.deleted_file)
      assert_equal('1910281', d.a_sha)
      assert_equal('3bd1f0e', d.b_sha)
      assert_equal("--- a/modified_added.txt\n+++ b/modified_added.txt\n@@ -1 +1,2 @@\n-foo\n\\ No newline at end of file\n+foo\n+bar\n", d.diff)
    end
  end

  def test_staged_modified_added_file_diff_is_correct
    in_temp_repo do |g|
      new_file('modified_added.txt', "foo")
      g.stage_files('modified_added.txt')
      new_file('modified_added.txt', "foo\nbar\n")

      s = g.status['modified_added.txt'].select(&:changes_staged?).first
      d = s.diff

      assert_not_nil(d)
      assert_equal('modified_added.txt', d.a_path)
      assert_equal('modified_added.txt', d.b_path)
      assert(d.new_file)
      assert(!d.deleted_file)
      assert_nil(d.a_sha)
      assert_equal('1910281', d.b_sha)
      assert_equal("--- /dev/null\n+++ b/modified_added.txt\n@@ -0,0 +1 @@\n+foo\n\\ No newline at end of file\n", d.diff)
    end
  end
end
