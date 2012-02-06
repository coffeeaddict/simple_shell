require 'open3'

# A very simple shell operations implementation
#
# == Synopsis
#
#  shell = SimpleShell.new
#  res = shell.ls
#  puts res.out
#  puts res.err
#  puts res.S?  (as $? wont work :->)
#
#  commands = shell.in("/other/path") do |sh|
#    sh.ls
#    sh.rm "-r", "bar"
#  end
#  puts commands.first.out
#
class SimpleShell
  attr_reader :commands

  def self.noisy
    @noisy ||= false
  end

  def self.noisy=(noise)
    @noisy = noise
  end

  # Create a new shell instance. This is tied to a base dir, which defaults to
  # Dir.pwd
  #
  #   SimpleShell.new
  #   SimpleShell.new("/path/to/base")
  #
  def initialize(base=Dir.pwd, env={})
    if base.is_a?(Hash)
      env  = base
      base = Dir.pwd
    end

    @base     = base
    @env      = env
    @commands = []
  end

  # open up a sub shell at another directory
  #
  #  shell.in("/path/to/other") do |sub_shell|
  #    sub_shell.system("ls")
  #    sub_shell.in("/path/to/third") do |sub_sub_shell|
  #      ...
  #   end
  #
  def in(dir, &block)
    dir = File.join(@base, dir) if !File.exists?(dir) || dir !~ /^\//

    shell = SimpleShell.new(dir, @env)
    yield shell
    return shell.commands
  end

  # perform a command on the shell
  #
  #   shell.system("ls")
  #   shell.do("ls")
  #   shell.command("ls")
  #
  # It is expected that arguments are provided as an array for security/safety
  # purposes:
  #
  #   shell.system("rm", "-r", "-f", "foo/")
  #
  # Returns a Command instance
  #
  def system(*args, &block)
    command = nil
    Dir.chdir(@base) do
      command = Command.new(@base, @env)
      command.execute(*args, &block)
    end

    @commands << command

    return command
  end
  alias_method :do, :system
  alias_method :command, :system

  # the S? of the last command
  def S?
    @commands.last.S?
  end

  # funkyness for neat little shell access
  #
  #   shell.ls              # = shell.system("ls")
  #   shell.rm %w(-rf foo/) # = shell.system("rm", "-rf", "foo/")
  #
  def method_missing(name, *args, &block)
    super
  rescue NoMethodError => e
    if args[0].is_a? Array
      args = args[0]
    end

    self.do(name.to_s, *args, &block)
  end

  # A command and it's output
  #
  # stdout and stderr are
  class Command
    attr_reader :out, :err, :S

    def initialize(base, env={})
      @base = base
      @env  = env

      @out = ""
      @err = ""
      @S   = -1
    end

    def execute(command, *args, &block)
      $stderr.puts("#{@env} #{command}, #{args}, #{@base}") if SimpleShell.noisy

      Open3.popen3(@env, "#{command}", *(args.collect { |a| "#{a}" }) , :chdir => @base) do |stdin, stdout, stderr, thread|
        if block_given?
          yield stdin
        end

        stdin.close

        # TODO : perhaps use blocks to put stuff into stdin

        @out = stdout.read.chomp
        @err = stderr.read.chomp
        @S   = thread.value rescue 0
      end
    end

    # cheap copy of $?
    def S?
      @S
    end

    # we just want to know the output of the command
    def to_s
      @out
    end
  end
end
