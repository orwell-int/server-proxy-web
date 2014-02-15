task :default => [:messages]

task :messages do
  `ruby-protoc -I ./messages -o app/ messages/*.proto`
end
