function flag=flag_count(S1,S2)
%S1是记录的APCE值，S2是记录的Fmax的值
S{1}=[mean(S2),mean(S1)];
S{2}=[mean(S2(1:end-1)),mean(S1(1:end-1))];
%S{3}=[mean(S2(1:end-2)),mean(S1(1:end-2))];

%根据置信度求flag的值
if (S2(end)/S{1}(1)<0.35) &&(S1(end)/S{1}(2)<=0.35) && S2(end)<0.1%区分好遮挡和旋转需要用到Fmax
   flag=2;
else
   if (S2(end)/S{1}(1)<0.35) &&(S1(end)/S{1}(2)<=0.35) && S2(end)>=0.1
       flag=1;
   else
       %if(S2(end)/S{1}(1)>=0.35) &&(S1(end)/S{1}(2)>=0.35)&&(S2(end-1)/S{2}(1)>=0.3)
       if(S2(end)/S{1}(1)>=0.35) &&(S1(end)/S{1}(2)>=0.35)&&(S2(end-1)/S{2}(1)>=0.3)
           flag=1;
       else
           flag=2;

       end
   end
end