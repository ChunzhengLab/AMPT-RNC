c=======================================================================
c     czcoal.f - Coalescence Module for AMPT
c     Author: CZ
c     Date: 2025-01-24
c     
c     This module provides two coalescence methods:
c     Method 1: Classic sequential coalescence (original AMPT)
c     Method 2: B/M competition coalescence (physics improved)
c=======================================================================

c-----------------------------------------------------------------------
c     Main coalescence interface
c-----------------------------------------------------------------------
      SUBROUTINE CZCOAL_MAIN()
c
      implicit double precision (a-h, o-z)
      double precision dpcoal,drcoal,ecritl,drbmRatio
      integer icoal_method
      common /czcoal_params/dpcoal,drcoal,ecritl,drbmRatio,icoal_method
      
c     write(6,*) 'CZCOAL_MAIN: using icoal_method=',icoal_method
      
      if(icoal_method.eq.1) then
         call czcoal_classic()
      elseif(icoal_method.eq.2) then
         call czcoal_bmcomp()
      else
         write(6,*) 'Error: Invalid coalescence method',icoal_method
         write(6,*) 'Valid options: 1=classic, 2=BM_competition'
         stop
      endif
      
      return
      end

c-----------------------------------------------------------------------
c     Method 1: Classic sequential coalescence (original coales)
c-----------------------------------------------------------------------
      SUBROUTINE CZCOAL_CLASSIC()
c
      PARAMETER (MAXSTR=150001)
      IMPLICIT DOUBLE PRECISION(D)
      DOUBLE PRECISION  gxp,gyp,gzp,ftp,pxp,pyp,pzp,pep,pmp
      DIMENSION IOVER(MAXSTR),dp1(2:3),dr1(2:3)
      DOUBLE PRECISION  PXSGS,PYSGS,PZSGS,PESGS,PMSGS,
     1     GXSGS,GYSGS,GZSGS,FTSGS
      double precision  dpcoal,drcoal,ecritl,drbmRatio
      integer icoal_method
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      common /czcoal_params/dpcoal,drcoal,ecritl,drbmRatio,icoal_method
      common /loclco/gxp(3),gyp(3),gzp(3),ftp(3),
     1     pxp(3),pyp(3),pzp(3),pep(3),pmp(3)
      COMMON/HJJET2/NSG,NJSG(MAXSTR),IASG(MAXSTR,3),K1SG(MAXSTR,100),
     &     K2SG(MAXSTR,100),PXSG(MAXSTR,100),PYSG(MAXSTR,100),
     &     PZSG(MAXSTR,100),PESG(MAXSTR,100),PMSG(MAXSTR,100)
      SAVE   
c      
      do 1001 ISG=1, NSG
         IOVER(ISG)=0
 1001 continue
C1     meson q coalesce with all available qbar:
      do 150 ISG=1,NSG
         if(NJSGS(ISG).ne.2.or.IOVER(ISG).eq.1) goto 150
C     DETERMINE CURRENT RELATIVE DISTANCE AND MOMENTUM:
         if(K2SGS(ISG,1).lt.0) then
            write(6,*) 'Antiquark appears in quark loop; stop'
            stop
         endif
c         
         do 1002 j=1,2
            ftp(j)=ftsgs(isg,j)
            gxp(j)=gxsgs(isg,j)
            gyp(j)=gysgs(isg,j)
            gzp(j)=gzsgs(isg,j)
            pxp(j)=pxsgs(isg,j)
            pyp(j)=pysgs(isg,j)
            pzp(j)=pzsgs(isg,j)
            pmp(j)=pmsgs(isg,j)
            pep(j)=pesgs(isg,j)
 1002    continue
         call czcoal_locldr(2,drlocl)
         dr0=drlocl
c     dp0^2 defined as (p1+p2)^2-(m1+m2)^2:
         dp0=dsqrt(2*(pep(1)*pep(2)-pxp(1)*pxp(2)
     &        -pyp(1)*pyp(2)-pzp(1)*pzp(2)-pmp(1)*pmp(2)))
c
         do 120 JSG=1,NSG
c     skip default or unavailable antiquarks:
            if(JSG.eq.ISG.or.IOVER(JSG).eq.1) goto 120
            if(NJSGS(JSG).eq.2) then
               ipmin=2
               ipmax=2
            elseif(NJSGS(JSG).eq.3.and.K2SGS(JSG,1).lt.0) then
               ipmin=1
               ipmax=3
            else
               goto 120
            endif
            do 100 ip=ipmin,ipmax
               dplocl=dsqrt(2*(pep(1)*pesgs(jsg,ip)
     1              -pxp(1)*pxsgs(jsg,ip)
     2              -pyp(1)*pysgs(jsg,ip)
     3              -pzp(1)*pzsgs(jsg,ip)
     4              -pmp(1)*pmsgs(jsg,ip)))
c     skip if outside of momentum radius:
               if(dplocl.gt.dpcoal) goto 120
               ftp(2)=ftsgs(jsg,ip)
               gxp(2)=gxsgs(jsg,ip)
               gyp(2)=gysgs(jsg,ip)
               gzp(2)=gzsgs(jsg,ip)
               pxp(2)=pxsgs(jsg,ip)
               pyp(2)=pysgs(jsg,ip)
               pzp(2)=pzsgs(jsg,ip)
               pmp(2)=pmsgs(jsg,ip)
               pep(2)=pesgs(jsg,ip)
               call czcoal_locldr(2,drlocl)
c     skip if outside of spatial radius:
               if(drlocl.gt.drcoal) goto 120
c     q_isg coalesces with qbar_jsg:
               if((dp0.gt.dpcoal.or.dr0.gt.drcoal)
     1              .or.(drlocl.lt.dr0)) then
                  dp0=dplocl
                  dr0=drlocl
                  call czcoal_exchge(isg,2,jsg,ip)
               endif
 100        continue
 120     continue
         if(dp0.le.dpcoal.and.dr0.le.drcoal) IOVER(ISG)=1
 150  continue
c
C2     meson qbar coalesce with all available q:
      do 250 ISG=1,NSG
         if(NJSGS(ISG).ne.2.or.IOVER(ISG).eq.1) goto 250
C     DETERMINE CURRENT RELATIVE DISTANCE AND MOMENTUM:
         do 1003 j=1,2
            ftp(j)=ftsgs(isg,j)
            gxp(j)=gxsgs(isg,j)
            gyp(j)=gysgs(isg,j)
            gzp(j)=gzsgs(isg,j)
            pxp(j)=pxsgs(isg,j)
            pyp(j)=pysgs(isg,j)
            pzp(j)=pzsgs(isg,j)
            pmp(j)=pmsgs(isg,j)
            pep(j)=pesgs(isg,j)
 1003    continue
         call czcoal_locldr(2,drlocl)
         dr0=drlocl
         dp0=dsqrt(2*(pep(1)*pep(2)-pxp(1)*pxp(2)
     &        -pyp(1)*pyp(2)-pzp(1)*pzp(2)-pmp(1)*pmp(2)))
c
         do 220 JSG=1,NSG
            if(JSG.eq.ISG.or.IOVER(JSG).eq.1) goto 220
            if(NJSGS(JSG).eq.2) then
               ipmin=1
               ipmax=1
            elseif(NJSGS(JSG).eq.3.and.K2SGS(JSG,1).gt.0) then
               ipmin=1
               ipmax=3
            else
               goto 220
            endif
            do 200 ip=ipmin,ipmax
               dplocl=dsqrt(2*(pep(2)*pesgs(jsg,ip)
     1              -pxp(2)*pxsgs(jsg,ip)
     2              -pyp(2)*pysgs(jsg,ip)
     3              -pzp(2)*pzsgs(jsg,ip)
     4              -pmp(2)*pmsgs(jsg,ip)))
c     skip if outside of momentum radius:
               if(dplocl.gt.dpcoal) goto 220
               ftp(1)=ftsgs(jsg,ip)
               gxp(1)=gxsgs(jsg,ip)
               gyp(1)=gysgs(jsg,ip)
               gzp(1)=gzsgs(jsg,ip)
               pxp(1)=pxsgs(jsg,ip)
               pyp(1)=pysgs(jsg,ip)
               pzp(1)=pzsgs(jsg,ip)
               pmp(1)=pmsgs(jsg,ip)
               pep(1)=pesgs(jsg,ip)
               call czcoal_locldr(2,drlocl)
c     skip if outside of spatial radius:
               if(drlocl.gt.drcoal) goto 220
c     qbar_isg coalesces with q_jsg:
               if((dp0.gt.dpcoal.or.dr0.gt.drcoal)
     1              .or.(drlocl.lt.dr0)) then
                  dp0=dplocl
                  dr0=drlocl
                  call czcoal_exchge(isg,1,jsg,ip)
               endif
 200        continue
 220     continue
         if(dp0.le.dpcoal.and.dr0.le.drcoal) IOVER(ISG)=1
 250  continue
c
C3     baryon q (antibaryon qbar) coalesce with all available q (qbar):
      do 350 ISG=1,NSG
         if(NJSGS(ISG).ne.3.or.IOVER(ISG).eq.1) goto 350
         ibaryn=K2SGS(ISG,1)
C     DETERMINE CURRENT RELATIVE DISTANCE AND MOMENTUM:
         do 1004 j=1,2
            ftp(j)=ftsgs(isg,j)
            gxp(j)=gxsgs(isg,j)
            gyp(j)=gysgs(isg,j)
            gzp(j)=gzsgs(isg,j)
            pxp(j)=pxsgs(isg,j)
            pyp(j)=pysgs(isg,j)
            pzp(j)=pzsgs(isg,j)
            pmp(j)=pmsgs(isg,j)
            pep(j)=pesgs(isg,j)
 1004    continue
         call czcoal_locldr(2,drlocl)
         dr1(2)=drlocl
         dp1(2)=dsqrt(2*(pep(1)*pep(2)-pxp(1)*pxp(2)
     &        -pyp(1)*pyp(2)-pzp(1)*pzp(2)-pmp(1)*pmp(2)))
c
         ftp(2)=ftsgs(isg,3)
         gxp(2)=gxsgs(isg,3)
         gyp(2)=gysgs(isg,3)
         gzp(2)=gzsgs(isg,3)
         pxp(2)=pxsgs(isg,3)
         pyp(2)=pysgs(isg,3)
         pzp(2)=pzsgs(isg,3)
         pmp(2)=pmsgs(isg,3)
         pep(2)=pesgs(isg,3)
         call czcoal_locldr(2,drlocl)
         dr1(3)=drlocl
         dp1(3)=dsqrt(2*(pep(1)*pep(2)-pxp(1)*pxp(2)
     &        -pyp(1)*pyp(2)-pzp(1)*pzp(2)-pmp(1)*pmp(2)))
c
         do 320 JSG=1,NSG
            if(JSG.eq.ISG.or.IOVER(JSG).eq.1) goto 320
            if(NJSGS(JSG).eq.2) then
               if(ibaryn.gt.0) then
                  ipmin=1
               else
                  ipmin=2
               endif
               ipmax=ipmin
            elseif(NJSGS(JSG).eq.3.and.
     1              (ibaryn*K2SGS(JSG,1)).gt.0) then
               ipmin=1
               ipmax=3
            else
               goto 320
            endif
            do 300 ip=ipmin,ipmax
               dplocl=dsqrt(2*(pep(1)*pesgs(jsg,ip)
     1              -pxp(1)*pxsgs(jsg,ip)
     2              -pyp(1)*pysgs(jsg,ip)
     3              -pzp(1)*pzsgs(jsg,ip)
     4              -pmp(1)*pmsgs(jsg,ip)))
c     skip if outside of momentum radius:
               if(dplocl.gt.dpcoal) goto 320
               ftp(2)=ftsgs(jsg,ip)
               gxp(2)=gxsgs(jsg,ip)
               gyp(2)=gysgs(jsg,ip)
               gzp(2)=gzsgs(jsg,ip)
               pxp(2)=pxsgs(jsg,ip)
               pyp(2)=pysgs(jsg,ip)
               pzp(2)=pzsgs(jsg,ip)
               pmp(2)=pmsgs(jsg,ip)
               pep(2)=pesgs(jsg,ip)
               call czcoal_locldr(2,drlocl)
c     skip if outside of spatial radius:
               if(drlocl.gt.drcoal) goto 320
c     q_isg may coalesce with q_jsg for a baryon:
               ipi=0
               if(dp1(2).gt.dpcoal.or.dr1(2).gt.drcoal) then
                  ipi=2
                  if((dp1(3).gt.dpcoal.or.dr1(3).gt.drcoal)
     1                 .and.dr1(3).gt.dr1(2)) ipi=3
               elseif(dp1(3).gt.dpcoal.or.dr1(3).gt.drcoal) then
                  ipi=3
               elseif(dr1(2).lt.dr1(3)) then
                  ipi=2
               else
                  ipi=3
               endif
               if((dplocl.lt.dp1(ipi).and.drlocl.lt.dr1(ipi))
     1              .or.drlocl.lt.dr1(ipi)) then
                  dp1(ipi)=dplocl
                  dr1(ipi)=drlocl
                  call czcoal_exchge(isg,ipi,jsg,ip)
               endif
 300        continue
 320     continue
         if((dp1(2).le.dpcoal.and.dr1(2).le.drcoal)
     1        .and.(dp1(3).le.dpcoal.and.dr1(3).le.drcoal)) 
     2        IOVER(ISG)=1
 350  continue
c
      RETURN
      END

c-----------------------------------------------------------------------
c     Method 2: B/M competition coalescence (simplified implementation)
c-----------------------------------------------------------------------
      SUBROUTINE CZCOAL_BMCOMP()
c
c     B/M competition coalescence with quark counting
c
      PARAMETER (MAXSTR=150001)
      IMPLICIT DOUBLE PRECISION(D)
      double precision  dpcoal,drcoal,ecritl,drbmRatio
      integer icoal_method,nq,nqbar
      DOUBLE PRECISION  PXSGS,PYSGS,PZSGS,PESGS,PMSGS,
     1     GXSGS,GYSGS,GZSGS,FTSGS
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      COMMON/HJJET2/NSG,NJSG(MAXSTR),IASG(MAXSTR,3),K1SG(MAXSTR,100),
     &     K2SG(MAXSTR,100),PXSG(MAXSTR,100),PYSG(MAXSTR,100),
     &     PZSG(MAXSTR,100),PESG(MAXSTR,100),PMSG(MAXSTR,100)
      common /czcoal_params/dpcoal,drcoal,ecritl,drbmRatio,icoal_method
      SAVE

c     Count quarks and antiquarks
      nq = 0
      nqbar = 0
      do i=1,NSG
         if(NJSGS(i).eq.2) then
c           Meson: 1 quark + 1 antiquark
            nq = nq + 1
            nqbar = nqbar + 1
         elseif(NJSGS(i).eq.3) then
c           Baryon or antibaryon: 3 quarks of same type
            if(K2SGS(i,1).gt.0) then
               nq = nq + 3      ! Baryon
            else
               nqbar = nqbar + 3  ! Antibaryon  
            endif
         endif
      enddo
      
      write(6,*) 'B/M competition: NSG=',NSG,', nq=',nq,', nqbar=',nqbar
      write(6,*) '  drbmRatio=',drbmRatio
      
c     For now, use classic algorithm
      call czcoal_classic()
      
      return
      end

c-----------------------------------------------------------------------
c     Shared utility functions
c-----------------------------------------------------------------------
      SUBROUTINE CZCOAL_LOCLDR(icall,drlocl)
c
      implicit double precision (a-h, o-z)
      dimension ftp0(3),pxp0(3),pyp0(3),pzp0(3),pep0(3)
      common /loclco/gxp(3),gyp(3),gzp(3),ftp(3),
     1     pxp(3),pyp(3),pzp(3),pep(3),pmp(3)
      common /prtn23/ gxp0(3),gyp0(3),gzp0(3),ft0fom
      common /lor/ enenew, pxnew, pynew, pznew
      SAVE   
c     for 2-body kinematics:
      if(icall.eq.2) then
         etot=pep(1)+pep(2)
         bex=(pxp(1)+pxp(2))/etot
         bey=(pyp(1)+pyp(2))/etot
         bez=(pzp(1)+pzp(2))/etot
c     boost the reference frame down by beta to get to the pair rest frame:
         do 1001 j=1,2
            beta2 = bex ** 2 + bey ** 2 + bez ** 2
            gam = 1.d0 / dsqrt(1.d0 - beta2)
            if(beta2.ge.0.9999999999999d0) then
               write(6,*) '4',pxp(1),pxp(2),pyp(1),pyp(2),
     1              pzp(1),pzp(2),pep(1),pep(2),pmp(1),pmp(2),
     2          dsqrt(pxp(1)**2+pyp(1)**2+pzp(1)**2+pmp(1)**2)/pep(1),
     3          dsqrt(pxp(1)**2+pyp(1)**2+pzp(1)**2)/pep(1)
               write(6,*) '4a',pxp(1)+pxp(2),pyp(1)+pyp(2),
     1              pzp(1)+pzp(2),etot
               write(6,*) '4b',bex,bey,bez,beta2,gam
            endif
c
            call lorenz(ftp(j),gxp(j),gyp(j),gzp(j),bex,bey,bez)
            gxp0(j)=pxnew
            gyp0(j)=pynew
            gzp0(j)=pznew
            ftp0(j)=enenew
            call lorenz(pep(j),pxp(j),pyp(j),pzp(j),bex,bey,bez)
            pxp0(j)=pxnew
            pyp0(j)=pynew
            pzp0(j)=pznew
            pep0(j)=enenew
 1001    continue
c     
         if(ftp0(1).ge.ftp0(2)) then
            ilate=1
            iearly=2
         else
            ilate=2
            iearly=1
         endif
         ft0fom=ftp0(ilate)
c     
         dt0=ftp0(ilate)-ftp0(iearly)
         gxp0(iearly)=gxp0(iearly)+pxp0(iearly)/pep0(iearly)*dt0
         gyp0(iearly)=gyp0(iearly)+pyp0(iearly)/pep0(iearly)*dt0
         gzp0(iearly)=gzp0(iearly)+pzp0(iearly)/pep0(iearly)*dt0
         drlocl=dsqrt((gxp0(ilate)-gxp0(iearly))**2
     1        +(gyp0(ilate)-gyp0(iearly))**2
     2        +(gzp0(ilate)-gzp0(iearly))**2)
c     for 3-body kinematics, used for baryons formation:
      elseif(icall.eq.3) then
         etot=pep(1)+pep(2)+pep(3)
         bex=(pxp(1)+pxp(2)+pxp(3))/etot
         bey=(pyp(1)+pyp(2)+pyp(3))/etot
         bez=(pzp(1)+pzp(2)+pzp(3))/etot
         beta2 = bex ** 2 + bey ** 2 + bez ** 2
         gam = 1.d0 / dsqrt(1.d0 - beta2)
         if(beta2.ge.0.9999999999999d0) then
            write(6,*) '5',bex,bey,bez,beta2,gam
         endif
c     boost the reference frame down by beta to get to the 3-parton rest frame:
         do 1002 j=1,3
            call lorenz(ftp(j),gxp(j),gyp(j),gzp(j),bex,bey,bez)
            gxp0(j)=pxnew
            gyp0(j)=pynew
            gzp0(j)=pznew
            ftp0(j)=enenew
            call lorenz(pep(j),pxp(j),pyp(j),pzp(j),bex,bey,bez)
            pxp0(j)=pxnew
            pyp0(j)=pynew
            pzp0(j)=pznew
            pep0(j)=enenew
 1002    continue
c     
         if(ftp0(1).gt.ftp0(2)) then
            ilate=1
            if(ftp0(3).gt.ftp0(1)) ilate=3
         else
            ilate=2
            if(ftp0(3).ge.ftp0(2)) ilate=3
         endif
         ft0fom=ftp0(ilate)
c     
         if(ilate.eq.1) then
            imin=2
            imax=3
            istep=1
         elseif(ilate.eq.2) then
            imin=1
            imax=3
            istep=2
         elseif(ilate.eq.3) then
            imin=1
            imax=2
            istep=1
         endif
c     
         do 1003 iearly=imin,imax,istep
            dt0=ftp0(ilate)-ftp0(iearly)
            gxp0(iearly)=gxp0(iearly)+pxp0(iearly)/pep0(iearly)*dt0
            gyp0(iearly)=gyp0(iearly)+pyp0(iearly)/pep0(iearly)*dt0
            gzp0(iearly)=gzp0(iearly)+pzp0(iearly)/pep0(iearly)*dt0
 1003    continue
      endif
c
      RETURN
      END

c-----------------------------------------------------------------------
      SUBROUTINE CZCOAL_EXCHGE(isg,ipi,jsg,ipj)
c
      implicit double precision  (a-h, o-z)
      PARAMETER (MAXSTR=150001)
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      SAVE   
c
      k1=K1SGS(isg,ipi)
      k2=K2SGS(isg,ipi)
      px=PXSGS(isg,ipi)
      py=PYSGS(isg,ipi)
      pz=PZSGS(isg,ipi)
      pe=PESGS(isg,ipi)
      pm=PMSGS(isg,ipi)
      gx=GXSGS(isg,ipi)
      gy=GYSGS(isg,ipi)
      gz=GZSGS(isg,ipi)
      ft=FTSGS(isg,ipi)
      K1SGS(isg,ipi)=K1SGS(jsg,ipj)
      K2SGS(isg,ipi)=K2SGS(jsg,ipj)
      PXSGS(isg,ipi)=PXSGS(jsg,ipj)
      PYSGS(isg,ipi)=PYSGS(jsg,ipj)
      PZSGS(isg,ipi)=PZSGS(jsg,ipj)
      PESGS(isg,ipi)=PESGS(jsg,ipj)
      PMSGS(isg,ipi)=PMSGS(jsg,ipj)
      GXSGS(isg,ipi)=GXSGS(jsg,ipj)
      GYSGS(isg,ipi)=GYSGS(jsg,ipj)
      GZSGS(isg,ipi)=GZSGS(jsg,ipj)
      FTSGS(isg,ipi)=FTSGS(jsg,ipj)
      K1SGS(jsg,ipj)=k1
      K2SGS(jsg,ipj)=k2
      PXSGS(jsg,ipj)=px
      PYSGS(jsg,ipj)=py
      PZSGS(jsg,ipj)=pz
      PESGS(jsg,ipj)=pe
      PMSGS(jsg,ipj)=pm
      GXSGS(jsg,ipj)=gx
      GYSGS(jsg,ipj)=gy
      GZSGS(jsg,ipj)=gz
      FTSGS(jsg,ipj)=ft
c
      RETURN
      END