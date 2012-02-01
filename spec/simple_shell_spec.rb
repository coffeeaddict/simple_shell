require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

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
  end
end
