$LOAD_PATH.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'fakefs'
require 'test/unit'

class FakeFSTest < Test::Unit::TestCase
  include FakeFS

  def setup
    FileSystem.clear
  end

  def test_can_be_initialized_empty
    fs = FileSystem
    assert_equal 0, fs.files.size
  end

  def xtest_can_be_initialized_with_an_existing_directory
    fs = FileSystem
    fs.clone(File.expand_path(File.dirname(__FILE__))).inspect
    puts fs.files.inspect
    assert_equal 1, fs.files.size
  end

  def test_can_create_directories
    FileUtils.mkdir_p("/path/to/dir")
    assert_kind_of FakeDir, FileSystem.fs['path']['to']['dir']
  end

  def test_knows_directories_exist
    FileUtils.mkdir_p(path = "/path/to/dir")
    assert File.exists?(path)
  end

  def test_knows_directories_are_directories
    FileUtils.mkdir_p(path = "/path/to/dir")
    assert File.directory?(path)
  end

  def test_knows_symlink_directories_are_directories
    FileUtils.mkdir_p(path = "/path/to/dir")
    FileUtils.ln_s path, sympath = '/sympath'
    assert File.directory?(sympath)
  end

  def test_knows_non_existent_directories_arent_directories
    path = 'does/not/exist/'
    assert_equal RealFile.directory?(path), File.directory?(path)
  end

  def test_doesnt_overwrite_existing_directories
    FileUtils.mkdir_p(path = "/path/to/dir")
    assert File.exists?(path)
    FileUtils.mkdir_p("/path/to")
    assert File.exists?(path)
  end

  def test_can_create_symlinks
    FileUtils.mkdir_p(target = "/path/to/target")
    FileUtils.ln_s(target, "/path/to/link")
    assert_kind_of FakeSymlink, FileSystem.fs['path']['to']['link']

    assert_raises(Errno::EEXIST) {
      FileUtils.ln_s(target, '/path/to/link')
    }
  end

  def test_can_follow_symlinks
    FileUtils.mkdir_p(target = "/path/to/target")
    FileUtils.ln_s(target, link = "/path/to/symlink")
    assert_equal target, File.readlink(link)
  end

  def test_knows_symlinks_are_symlinks
    FileUtils.mkdir_p(target = "/path/to/target")
    FileUtils.ln_s(target, link = "/path/to/symlink")
    assert File.symlink?(link)
  end

  def test_can_create_files
    path = '/path/to/file.txt'
    File.open(path, 'w') do |f|
      f.write "Yatta!"
    end

    assert File.exists?(path)
  end

  def test_can_read_files_once_written
    path = '/path/to/file.txt'
    File.open(path, 'w') do |f|
      f.write "Yatta!"
    end

    assert_equal "Yatta!", File.read(path)
  end

  def test_can_write_to_files
    path = '/path/to/file.txt'
    File.open(path, 'w') do |f|
      f << 'Yada Yada'
    end
    assert_equal 'Yada Yada', File.read(path)
  end

  def test_can_read_with_File_readlines
    path = '/path/to/file.txt'
    File.open(path, 'w') do |f|
      f.puts "Yatta!", "Gatta!"
      f.puts ["woot","toot"]
    end

    assert_equal %w(Yatta! Gatta! woot toot), File.readlines(path)
  end

  def test_File_close_disallows_further_access
    path = '/path/to/file.txt'
    file = File.open(path, 'w')
    file.write 'Yada'
    file.close
    assert_raise IOError do
      file.read
    end
  end

  def test_can_read_from_file_objects
    path = '/path/to/file.txt'
    File.open(path, 'w') do |f|
      f.write "Yatta!"
    end

    assert_equal "Yatta!", File.new(path).read
  end

  def test_file_read_errors_appropriately
    assert_raise Errno::ENOENT do
      File.read('anything')
    end
  end

  def test_knows_files_are_files
    path = '/path/to/file.txt'
    File.open(path, 'w') do |f|
      f.write "Yatta!"
    end

    assert File.file?(path)
  end

  def test_knows_symlink_files_are_files
    path = '/path/to/file.txt'
    File.open(path, 'w') do |f|
      f.write "Yatta!"
    end
    FileUtils.ln_s path, sympath='/sympath'

    assert File.file?(sympath)
  end

  def test_knows_non_existent_files_arent_files
    assert_equal RealFile.file?('does/not/exist.txt'), File.file?('does/not/exist.txt')
  end

  def test_can_chown_files
    good = 'file.txt'
    bad = 'nofile.txt'
    File.open(good,'w'){|f| f.write "foo" }

    assert_equal [good], FileUtils.chown('noone', 'nogroup', good, :verbose => true)
    assert_raises(Errno::ENOENT) do
      FileUtils.chown('noone', 'nogroup', bad, :verbose => true)
    end

    assert_equal [good], FileUtils.chown('noone', 'nogroup', good)
    assert_raises(Errno::ENOENT) do
      FileUtils.chown('noone', 'nogroup', bad)
    end

    assert_equal [good], FileUtils.chown('noone', 'nogroup', [good])
    assert_raises(Errno::ENOENT) do
      FileUtils.chown('noone', 'nogroup', [good, bad])
    end
  end

  def test_can_chown_R_files
    FileUtils.mkdir_p '/path/'
    File.open('/path/foo', 'w'){|f| f.write 'foo' }
    File.open('/path/foobar', 'w'){|f| f.write 'foo' }
    resp = FileUtils.chown_R('no', 'no', '/path')
    assert_equal ['/path'], resp
  end

  def test_dir_globs_paths
    FileUtils.mkdir_p '/path'
    File.open('/path/foo', 'w'){|f| f.write 'foo' }
    File.open('/path/foobar', 'w'){|f| f.write 'foo' }

    FileUtils.mkdir_p '/path/bar'
    File.open('/path/bar/baz', 'w'){|f| f.write 'foo' }

    FileUtils.cp_r '/path/bar', '/path/bar2'

    assert_equal  ['/path'], Dir['/path']
    assert_equal %w( /path/bar /path/bar2 /path/foo /path/foobar ), Dir['/path/*']

    assert_equal ['/path/bar/baz'], Dir['/path/bar/*']
    assert_equal ['/path/foo'], Dir['/path/foo']

    assert_equal ['/path'], Dir['/path*']
    assert_equal ['/path/foo', '/path/foobar'], Dir['/p*h/foo*']
    assert_equal ['/path/foo', '/path/foobar'], Dir['/p??h/foo*']

    FileUtils.cp_r '/path', '/otherpath'

    assert_equal %w( /otherpath/foo /otherpath/foobar /path/foo /path/foobar ), Dir['/*/foo*']
  end

  def test_dir_glob_handles_root
    FileUtils.mkdir_p '/path'

    # this fails. the root dir should be named '/' but it is '.'
    #assert_equal ['/'], Dir['/']
  end

  def test_chdir_changes_directories_like_a_boss
    # I know memes!
    FileUtils.mkdir_p '/path'
    assert_equal '.', FileSystem.fs.name
    assert_equal({}, FileSystem.fs['path'])
    Dir.chdir '/path' do
      File.open('foo', 'w'){|f| f.write 'foo'}
      File.open('foobar', 'w'){|f| f.write 'foo'}
    end

    assert_equal '.', FileSystem.fs.name
    assert_equal(['foo', 'foobar'], FileSystem.fs['path'].keys.sort)

    c = nil
    Dir.chdir '/path' do
      c = File.open('foo', 'r'){|f| f.read }
    end

    assert_equal 'foo', c
  end

  def test_chdir_shouldnt_keep_us_from_absolute_paths
    FileUtils.mkdir_p '/path'

    Dir.chdir '/path' do
      File.open('foo', 'w'){|f| f.write 'foo'}
      File.open('/foobar', 'w'){|f| f.write 'foo'}
    end
    assert_equal ['foo'], FileSystem.fs['path'].keys.sort
    assert_equal ['foobar', 'path'], FileSystem.fs.keys.sort

    Dir.chdir '/path' do
      FileUtils.rm('foo')
      FileUtils.rm('/foobar')
    end

    assert_equal [], FileSystem.fs['path'].keys.sort
    assert_equal ['path'], FileSystem.fs.keys.sort
  end

  def test_chdir_should_be_nestable
    FileUtils.mkdir_p '/path/me'
    Dir.chdir '/path' do
      File.open('foo', 'w'){|f| f.write 'foo'}
      Dir.chdir 'me' do
        File.open('foobar', 'w'){|f| f.write 'foo'}
      end
    end

    assert_equal ['foo','me'], FileSystem.fs['path'].keys.sort
    assert_equal ['foobar'], FileSystem.fs['path']['me'].keys.sort
  end

  def test_chdir_should_flop_over_and_die_if_the_dir_doesnt_exist
    assert_raise(Errno::ENOENT) do
      Dir.chdir('/nope') do
        1
      end
    end
  end

  def test_chdir_shouldnt_lose_state_because_of_errors
    FileUtils.mkdir_p '/path'

    Dir.chdir '/path' do
      File.open('foo', 'w'){|f| f.write 'foo'}
      File.open('foobar', 'w'){|f| f.write 'foo'}
    end

    begin
      Dir.chdir('/path') do
        raise Exception
      end
    rescue Exception # hardcore
    end

    Dir.chdir('/path') do
      begin
        Dir.chdir('nope'){ }
      rescue Errno::ENOENT
      end

      assert_equal ['/path'], FileSystem.dir_levels
    end

    assert_equal(['foo', 'foobar'], FileSystem.fs['path'].keys.sort)
  end

  def test_chdir_with_no_block_is_awesome
    FileUtils.mkdir_p '/path'
    Dir.chdir('/path')
    FileUtils.mkdir_p 'subdir'
    assert_equal ['subdir'], FileSystem.current_dir.keys
    Dir.chdir('subdir')
    File.open('foo', 'w'){|f| f.write 'foo'}
    assert_equal ['foo'], FileSystem.current_dir.keys

    assert_raises(Errno::ENOENT) do
      Dir.chdir('subsubdir')
    end

    assert_equal ['foo'], FileSystem.current_dir.keys
  end

  def test_current_dir_reflected_by_pwd
    FileUtils.mkdir_p '/path'
    Dir.chdir('/path')

    assert_equal '/path', Dir.pwd
    assert_equal '/path', Dir.getwd

    FileUtils.mkdir_p 'subdir'
    Dir.chdir('subdir')

    assert_equal '/path/subdir', Dir.pwd
    assert_equal '/path/subdir', Dir.getwd
  end

  def test_file_open_defaults_to_read
    File.open('foo','w'){|f| f.write 'bar' }
    assert_equal 'bar', File.open('foo'){|f| f.read }
  end

  def test_flush_exists_on_file
    r = File.open('foo','w'){|f| f.write 'bar';  f.flush }
    assert_equal 'foo', r.path
  end

  def test_mv_should_raise_error_on_missing_file
    assert_raise(Errno::ENOENT) do
      FileUtils.mv 'blafgag', 'foo'
    end
  end

  def test_mv_actually_works
    File.open('foo', 'w') {|f| f.write 'bar' }
    FileUtils.mv 'foo', 'baz'
    assert_equal 'bar', File.open('baz'){|f| f.read }
  end

  def test_cp_actually_works
    File.open('foo', 'w') {|f| f.write 'bar' }
    FileUtils.cp('foo', 'baz')
    assert_equal 'bar', File.read('baz')
  end

  def test_cp_file_into_dir
    File.open('foo', 'w') {|f| f.write 'bar' }
    FileUtils.mkdir_p 'baz'

    FileUtils.cp('foo', 'baz')
    assert_equal 'bar', File.read('baz/foo')
  end

  def test_cp_overwrites_dest_file
    File.open('foo', 'w') {|f| f.write 'FOO' }
    File.open('bar', 'w') {|f| f.write 'BAR' }

    FileUtils.cp('foo', 'bar')
    assert_equal 'FOO', File.read('bar')
  end

  def test_cp_fails_on_no_source
    assert_raise Errno::ENOENT do
      FileUtils.cp('foo', 'baz')
    end
  end

  def test_cp_fails_on_directory_copy
    FileUtils.mkdir_p 'baz'

    assert_raise Errno::EISDIR do
      FileUtils.cp('baz', 'bar')
    end
  end

  def test_cp_r_doesnt_tangle_files_together
    File.open('foo', 'w') {|f| f.write 'bar' }
    FileUtils.cp_r('foo', 'baz')
    File.open('baz', 'w') {|f| f.write 'quux' }
    assert_equal 'bar', File.open('foo'){|f| f.read }
  end

  def test_cp_r_should_raise_error_on_missing_file
    # Yes, this error sucks, but it conforms to the original Ruby
    # method.
    assert_raise(RuntimeError) do
      FileUtils.cp_r 'blafgag', 'foo'
    end
  end

  def test_cp_r_handles_copying_directories
    FileUtils.mkdir_p 'subdir'
    Dir.chdir('subdir'){ File.open('foo', 'w'){|f| f.write 'footext' } }

    FileUtils.mkdir_p 'baz'

    # To a previously uncreated directory
    FileUtils.cp_r('subdir', 'quux')
    assert_equal 'footext', File.open('quux/foo'){|f| f.read }

    # To a directory that already exists
    FileUtils.cp_r('subdir', 'baz')
    assert_equal 'footext', File.open('baz/subdir/foo'){|f| f.read }

    # To a subdirectory of a directory that does not exist
    assert_raises(Errno::ENOENT) {
      FileUtils.cp_r('subdir', 'nope/something')
    }
  end

  def test_cp_r_only_copies_into_directories
    FileUtils.mkdir_p 'subdir'
    Dir.chdir('subdir'){ File.open('foo', 'w'){|f| f.write 'footext' } }

    File.open('bar', 'w') {|f| f.write 'bartext' }

    assert_raises(Errno::EEXIST) do
      FileUtils.cp_r 'subdir', 'bar'
    end

    FileUtils.mkdir_p 'otherdir'
    FileUtils.ln_s 'otherdir', 'symdir'

    FileUtils.cp_r 'subdir', 'symdir'
    assert_equal 'footext', File.open('symdir/subdir/foo'){|f| f.read }
  end

  def test_cp_r_sets_parent_correctly
    FileUtils.mkdir_p '/path/foo'
    File.open('/path/foo/bar', 'w'){|f| f.write 'foo' }
    File.open('/path/foo/baz', 'w'){|f| f.write 'foo' }

    FileUtils.cp_r '/path/foo', '/path/bar'

    assert File.exists?('/path/bar/baz')
    FileUtils.rm_rf '/path/bar/baz'
    assert_equal %w( /path/bar/bar ), Dir['/path/bar/*']
  end

  def test_clone_clones_normal_files
    RealFile.open(here('foo'), 'w'){|f| f.write 'bar' }
    assert !File.exists?(here('foo'))
    FileSystem.clone(here('foo'))
    assert_equal 'bar', File.open(here('foo')){|f| f.read }
  ensure
    RealFile.unlink(here('foo')) if RealFile.exists?(here('foo'))
  end

  def test_clone_clones_directories
    RealFileUtils.mkdir_p(here('subdir'))

    FileSystem.clone(here('subdir'))

    assert File.exists?(here('subdir')), 'subdir was cloned'
    assert File.directory?(here('subdir')), 'subdir is a directory'
  ensure
    RealFileUtils.rm_rf(here('subdir')) if RealFile.exists?(here('subdir'))
  end

  def test_clone_clones_dot_files_even_hard_to_find_ones
    RealFileUtils.mkdir_p(here('subdir/.bar/baz/.quux/foo'))
    assert !File.exists?(here('subdir'))

    FileSystem.clone(here('subdir'))
    assert_equal ['.bar'], FileSystem.find(here('subdir')).keys
    assert_equal ['foo'], FileSystem.find(here('subdir/.bar/baz/.quux')).keys
  ensure
    RealFileUtils.rm_rf(here('subdir')) if RealFile.exists?(here('subdir'))
  end

  def test_putting_a_dot_at_end_copies_the_contents
    FileUtils.mkdir_p 'subdir'
    Dir.chdir('subdir'){ File.open('foo', 'w'){|f| f.write 'footext' } }

    FileUtils.mkdir_p 'newdir'
    FileUtils.cp_r 'subdir/.', 'newdir'
    assert_equal 'footext', File.open('newdir/foo'){|f| f.read }
  end

  def test_file_can_read_from_symlinks
    File.open('first', 'w'){|f| f.write '1'}
    FileUtils.ln_s 'first', 'one'
    assert_equal '1', File.open('one'){|f| f.read }

    FileUtils.mkdir_p 'subdir'
    File.open('subdir/nother','w'){|f| f.write 'works' }
    FileUtils.ln_s 'subdir', 'new'
    assert_equal 'works', File.open('new/nother'){|f| f.read }
  end

  def test_files_can_be_touched
    FileUtils.touch('touched_file')
    assert File.exists?('touched_file')
    list = ['newfile', 'another']
    FileUtils.touch(list)
    list.each { |fp| assert(File.exists?(fp)) }
  end

  def test_touch_does_not_work_if_the_dir_path_cannot_be_found
    assert_raises(Errno::ENOENT) {
      FileUtils.touch('this/path/should/not/be/here')
    }
    FileUtils.mkdir_p('subdir')
    list = ['subdir/foo', 'nosubdir/bar']

    assert_raises(Errno::ENOENT) {
      FileUtils.touch(list)
    }
  end

  def here(fname)
    RealFile.expand_path(RealFile.dirname(__FILE__)+'/'+fname)
  end
end
