require "xmlrpc/client"

server = XMLRPC::Client.new("127.0.0.1", "/questionserver",80)
begin
  param = server.call("QuestionServer.hello")
  puts "#{param}"
rescue XMLRPC::FaultException => e
  puts "Error:"
  puts e.faultCode
  puts e.faultString
end
