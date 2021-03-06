require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

class Float
  def at_least?(x)
    self >= x
  end
end

describe SimpleShell do
  let (:shell) { SimpleShell.new }

  it "should keep track of perfomed commands" do
    shell.ls
    shell.ls

    shell.commands.count.should == 2
  end

  it "should remember the last exit status" do
    shell.ls "/path/non/existant"
    shell.S?.to_i.should_not == 0

    shell.ls
    shell.S?.to_i.should == 0
  end

  it "should perform system commands" do
    c = shell.system("ls -la")

    c.out.should_not be_empty
    c.err.should be_empty
    c.S?.to_i.should == 0
  end

  it "should allow a sub shell" do
    shell.ls
    shell.ls

    commands = shell.in("/tmp") do |sub|
      sub.ls
    end

    commands.should be_kind_of(Array)
    commands.count.should == 1

    shell.commands.count.should == 2
  end

  it "should allow a sub shell with relative paths" do
    shell.mkdir "-p", "here"
    shell.in("here") do |sh|
      sh.do :touch, "here_file"
    end

    shell.ls("here").out.split("\n").should include("here_file")
    shell.rm "-rf", "here"
  end


  it "should use blocks to write on stdin" do
    res = shell.wc("-w") do |pipe|
      pipe.puts "I was echoed"
    end

    res.out.should == "3"
  end

  it "should be settable to noisy" do
    SimpleShell.noisy = true
    SimpleShell.noisy.should be_true

    SimpleShell.noisy = false
    SimpleShell.noisy.should be_false
  end

  it "should allow for environment setting" do
    shell = SimpleShell.new({ 'MY_ENV' => 'my environment' })
    shell.printenv.out.should =~ /my environment/

    shell = SimpleShell.new()
    shell.printenv.out.should_not =~ /my environment/
  end

  it "should capture stdout" do
    res = shell.do("./spec/support/echo.sh")
    res.out.should == "hello\nworld"
  end

  it "should capture stderr" do
    res = shell.do("./spec/support/echo_stderr.sh")
    res.err.should == "goodbye\nworld"
  end


  describe "Handlers" do
    it "should pass captured lines on stdout" do
      buffer  = []
      shell.stdout_handler = ->(line) {
        buffer << line
      }

      res = shell.echo "hello\nworld"
      res.out.should be_nil
      res.err.should be_empty

      buffer.count.should == 2
    end

    it "should pass captured lines on stderr" do
      buffer  = []
      shell.stderr_handler = ->(line) {
        buffer << line
      }

      res = shell.do "./spec/support/echo_stderr.sh"
      res.out.should be_empty
      res.err.should be_nil

      buffer.count.should == 2
    end

    it "should wait for long running processes" do
      buffer = []
      shell.stdout_handler = ->(line) {
        buffer << line
      }

      start = Time.now
      shell.do "./spec/support/long_running.sh"

      (Time.now - start).should be_at_least 2
      buffer.count.should == 3
    end
  end
end
