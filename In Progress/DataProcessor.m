classdef DataProcessor < yarp.PortReader
    %UNTITLED2 Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        %connection;
    end
    
    methods (Access = public)
        %function blaa=DataProcessor()
         %   import yarp.PortReader;
          %  import yarp.ConnectionReader;
        %end
        
        function thebool = read(connection)
            
            b=yarp.Bottle;
            b.read(connection);
            % process data in b
            b
            thebool=true;
            %return thebool;
        end
    end
    
end

