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
      PARAMETER (MAXSTR=150001, MAXPTN=400001)
      double precision dpcoal,drcoal,ecritl,drbmRatio,mesonBaryonRatio
      integer icoal_method,nq_init,nqbar_init,nq_final,nqbar_final
      integer nmeson,nbaryon,nantibaryon,NSG
      INTEGER  K1SGS,K2SGS,NJSGS
      DOUBLE PRECISION  PXSGS,PYSGS,PZSGS,PESGS,PMSGS,
     1     GXSGS,GYSGS,GZSGS,FTSGS
      common /czcoal_params/dpcoal,drcoal,ecritl,drbmRatio,
     1     mesonBaryonRatio,icoal_method
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      COMMON/HJJET2/NSG
      character*20 method_name

c     Count initial quarks and antiquarks
      call czcoal_count_initial(nq_init,nqbar_init)

c     Set method name for output
      if(icoal_method.eq.1) then
         method_name = 'Classic'
      elseif(icoal_method.eq.2) then
         method_name = 'B/M Competition'
      elseif(icoal_method.eq.3) then
         method_name = 'Random'
      else
         write(6,*) 'Error: Invalid coalescence method',icoal_method
         write(6,*) 'Valid: 1=classic, 2=BM_competition, 3=random'
         stop
      endif

c     Print initial state
      write(6,*) 
      write(6,'(A,A20)') ' === Coalescence Method: ',method_name
      write(6,'(A,I6,A,I6)') ' Initial state: nq=',nq_init,
     &     ', nqbar=',nqbar_init

c     Call appropriate coalescence method
      if(icoal_method.eq.1) then
         call czcoal_classic()
      elseif(icoal_method.eq.2) then
         call czcoal_bmcomp()
      elseif(icoal_method.eq.3) then
         call czcoal_random()
      endif

c     Count final state
      call czcoal_count_final(nq_final,nqbar_final,
     &     nmeson,nbaryon,nantibaryon)

c     Print unified output
      write(6,'(A,I5,A,I5,A,I5)') ' Hadrons formed: mesons=',nmeson,
     &     ', baryons=',nbaryon,', antibaryons=',nantibaryon
      write(6,'(A,I6,A,I6)') ' Remaining: nq=',nq_final,
     &     ', nqbar=',nqbar_final
      write(6,*) ' ================================='
      write(6,*)

      return
      end

c-----------------------------------------------------------------------
c     Method 1: Classic sequential coalescence (original coales)
c-----------------------------------------------------------------------
      SUBROUTINE CZCOAL_CLASSIC()
c
      PARAMETER (MAXSTR=150001)
      implicit double precision (a-h, o-z)
      DOUBLE PRECISION  gxp,gyp,gzp,ftp,pxp,pyp,pzp,pep,pmp
      DOUBLE PRECISION  drlocl,dplocl
      DIMENSION IOVER(MAXSTR),dp1(2:3),dr1(2:3)
      DOUBLE PRECISION  PXSGS,PYSGS,PZSGS,PESGS,PMSGS,
     1     GXSGS,GYSGS,GZSGS,FTSGS
      INTEGER  K1SGS,K2SGS,NJSGS
      double precision  dpcoal,drcoal,ecritl,drbmRatio,mesonBaryonRatio
      integer icoal_method
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      common /czcoal_params/dpcoal,drcoal,ecritl,drbmRatio,
     1     mesonBaryonRatio,icoal_method
      common /loclco/gxp(3),gyp(3),gzp(3),ftp(3),
     1     pxp(3),pyp(3),pzp(3),pep(3),pmp(3)
      COMMON/HJJET2/NSG
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
c      Method 2: B/M competition coalescence
c-----------------------------------------------------------------------
      SUBROUTINE CZCOAL_BMCOMP()
c
c     B/M competition coalescence algorithm
c
      PARAMETER (MAXSTR=150001)
      implicit double precision (a-h, o-z)
      PARAMETER (MAXPTN=400001,drbig=1d9)
      double precision  dpcoal,drcoal,ecritl,drbmRatio,mesonBaryonRatio
      integer icoal_method,nq,nqbar
      DOUBLE PRECISION  PXSGS,PYSGS,PZSGS,PESGS,PMSGS,
     1     GXSGS,GYSGS,GZSGS,FTSGS
      INTEGER  K1SGS,K2SGS,NJSGS,NSG,ITYP5
      DOUBLE PRECISION  gxp,gyp,gzp,ftp,pxp,pyp,pzp,pep,pmp
      DOUBLE PRECISION  GX5, GY5, GZ5, FT5, PX5, PY5, PZ5, E5, XMASS5
      DIMENSION IOVER(MAXPTN)
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      COMMON/HJJET2/NSG
      COMMON /prec2/GX5(MAXPTN),GY5(MAXPTN),GZ5(MAXPTN),FT5(MAXPTN),
     &     PX5(MAXPTN), PY5(MAXPTN), PZ5(MAXPTN), E5(MAXPTN),
     &     XMASS5(MAXPTN), ITYP5(MAXPTN)
      COMMON /PARA1/ MUL
      common /loclco/gxp(3),gyp(3),gzp(3),ftp(3),
     1     pxp(3),pyp(3),pzp(3),pep(3),pmp(3)
      common /czcoal_params/dpcoal,drcoal,ecritl,drbmRatio,
     1     mesonBaryonRatio,icoal_method
      SAVE

c     drbmRatio comes from common block (configurable)

c     Convert /SOFT/ data to /prec2/ format
      call czcoal_soft_to_prec2(nq, nqbar)

c     Removed: individual method output now handled in CZCOAL_MAIN

c     Call B/M competition coalescence algorithm
      call czcoal_bmcomp_core(nq, nqbar)

c     No need to convert back - algorithm already writes to /SOFT/

      return
      end

c-----------------------------------------------------------------------
c     Data conversion functions for B/M competition
c-----------------------------------------------------------------------
      SUBROUTINE czcoal_soft_to_prec2(nq, nqbar)
c
c     Convert /SOFT/ format to /prec2/ format for newHF algorithm
c     Expand grouped partons to individual partons
c
      PARAMETER (MAXSTR=150001, MAXPTN=400001)
      implicit double precision (a-h, o-z)
      DOUBLE PRECISION  PXSGS,PYSGS,PZSGS,PESGS,PMSGS,
     1     GXSGS,GYSGS,GZSGS,FTSGS
      INTEGER  K1SGS,K2SGS,NJSGS,NSG,ITYP5
      DOUBLE PRECISION  GX5, GY5, GZ5, FT5, PX5, PY5, PZ5, E5, XMASS5
      integer nq,nqbar
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      COMMON/HJJET2/NSG
      COMMON /prec2/GX5(MAXPTN),GY5(MAXPTN),GZ5(MAXPTN),FT5(MAXPTN),
     &     PX5(MAXPTN), PY5(MAXPTN), PZ5(MAXPTN), E5(MAXPTN),
     &     XMASS5(MAXPTN), ITYP5(MAXPTN)
      COMMON /PARA1/ MUL
      SAVE

c     Convert grouped partons in /SOFT/ to individual partons in /prec2/
      MUL = 0
      nq = 0
      nqbar = 0

      do isg=1,NSG
         if(NJSGS(isg).eq.0) cycle

         do ip=1,NJSGS(isg)
            MUL = MUL + 1
            if(MUL.gt.MAXPTN) then
               write(6,*) 'czcoal_soft_to_prec2: MUL exceeds MAXPTN'
               stop
            endif

c           Copy parton data
            GX5(MUL) = GXSGS(isg,ip)
            GY5(MUL) = GYSGS(isg,ip)
            GZ5(MUL) = GZSGS(isg,ip)
            FT5(MUL) = FTSGS(isg,ip)
            PX5(MUL) = PXSGS(isg,ip)
            PY5(MUL) = PYSGS(isg,ip)
            PZ5(MUL) = PZSGS(isg,ip)
            E5(MUL) = PESGS(isg,ip)
            XMASS5(MUL) = PMSGS(isg,ip)

c           Set parton type: positive for quarks, negative for antiquarks
            if(K2SGS(isg,ip).gt.0) then
               ITYP5(MUL) = K2SGS(isg,ip)    ! Keep flavor info
               nq = nq + 1
            else
               ITYP5(MUL) = K2SGS(isg,ip)    ! Keep flavor info (negative)
               nqbar = nqbar + 1
            endif
         enddo
      enddo

      return
      end

c-----------------------------------------------------------------------
      SUBROUTINE czcoal_setPtoH(isg,npmb,ip1,ip2,ip3)
c
c     Set partons to hadron - copy from /prec2/ to /SOFT/
c     (Adapted from newHF setPtoH)
c
      implicit double precision  (a-h, o-z)
      PARAMETER (MAXSTR=150001, MAXPTN=400001)
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      COMMON /prec2/GX5(MAXPTN),GY5(MAXPTN),GZ5(MAXPTN),FT5(MAXPTN),
     &     PX5(MAXPTN), PY5(MAXPTN), PZ5(MAXPTN), E5(MAXPTN),
     &     XMASS5(MAXPTN), ITYP5(MAXPTN)
      SAVE
c
      NJSGS(isg)=npMB
      do ipH=1,npmb
         if(ipH.eq.1) then
            ip=ip1
         elseif(ipH.eq.2) then
            ip=ip2
         else
            ip=ip3
         endif
         K2SGS(isg,ipH)=ITYP5(ip)
         PXSGS(isg,ipH)=PX5(ip)
         PYSGS(isg,ipH)=PY5(ip)
         PZSGS(isg,ipH)=PZ5(ip)
         PESGS(isg,ipH)=E5(ip)
         PMSGS(isg,ipH)=XMASS5(ip)
         GXSGS(isg,ipH)=GX5(ip)
         GYSGS(isg,ipH)=GY5(ip)
         GZSGS(isg,ipH)=GZ5(ip)
         FTSGS(isg,ipH)=FT5(ip)
      enddo
c
      RETURN
      END

c-----------------------------------------------------------------------
      SUBROUTINE czcoal_bmcomp_core(nq, nqbar)
c
c     newHF B/M competition coalescence algorithm (simplified)
c     Adapted from newHF coales subroutine
c
      implicit double precision (a-h, o-z)
      PARAMETER (MAXSTR=150001, MAXPTN=400001, drbig=1d9)
      DOUBLE PRECISION  gxp,gyp,gzp,ftp,pxp,pyp,pzp,pep,pmp
      INTEGER  K1SGS,K2SGS,NJSGS,NSG,ITYP5
      DOUBLE PRECISION  GX5, GY5, GZ5, FT5, PX5, PY5, PZ5, E5, XMASS5
      double precision  dpcoal,drcoal,ecritl,drbmRatio,mesonBaryonRatio
      double precision  gxp0,gyp0,gzp0,ft0fom,drlocl,drlot
      double precision  drlo1,drlo2,drlo3,drlo1t,drlo2t,drlo3t
      double precision  dr0,dr0m,dr0b1,drAvg,drAvg0,dp0,dplocl
      integer nq,nqbar,npmb,nsmm1,nsmb1,nsmab1
      DIMENSION IOVER(MAXPTN)
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      COMMON/HJJET2/NSG
      COMMON /prec2/GX5(MAXPTN),GY5(MAXPTN),GZ5(MAXPTN),FT5(MAXPTN),
     &     PX5(MAXPTN), PY5(MAXPTN), PZ5(MAXPTN), E5(MAXPTN),
     &     XMASS5(MAXPTN), ITYP5(MAXPTN)
      COMMON /PARA1/ MUL
      common /loclco/gxp(3),gyp(3),gzp(3),ftp(3),
     1     pxp(3),pyp(3),pzp(3),pep(3),pmp(3)
      common /prtn23/ gxp0(3),gyp0(3),gzp0(3),ft0fom,drlocl,drlot,
     1     drlo1,drlo2,drlo3,drlo1t,drlo2t,drlo3t
      common /para7/ ioscar,nsmm0,nsmb0,nsmab0,nsmm1,nsmb1,nsmab1
      common /czcoal_params/dpcoal,drcoal,ecritl,drbmRatio,
     1     mesonBaryonRatio,icoal_method
      SAVE

c     Initialize
      isg=0
      nsmm1=0
      nsmb1=0
      nsmab1=0
      do ip=1,mul
         IOVER(ip)=0
      enddo

c     First sort partons by freeze-out time
      call czcoal_parORD()

c     Main loop over partons
      do 350 ip1=1,mul-1
c        Skip used partons
         if(IOVER(ip1).eq.1) goto 350
         IOVER(ip1)=1


c        Load first parton data
         gxp(1)=gx5(ip1)
         gyp(1)=gy5(ip1)
         gzp(1)=gz5(ip1)
         ftp(1)=ft5(ip1)
         pxp(1)=px5(ip1)
         pyp(1)=py5(ip1)
         pzp(1)=pz5(ip1)
         pep(1)=e5(ip1)
         pmp(1)=xmass5(ip1)

         dr0m=drbig
         dr0b1=drbig

c        Find best meson partner
         ip2m=0
         do 120 ip2=ip1+1,mul
            if(IOVER(ip2).eq.1) goto 120
c           Check if opposite charge (meson condition)
            if((ITYP5(ip1)*ITYP5(ip2)).ge.0) goto 120

c           Load second parton
            gxp(2)=gx5(ip2)
            gyp(2)=gy5(ip2)
            gzp(2)=gz5(ip2)
            ftp(2)=ft5(ip2)
            pxp(2)=px5(ip2)
            pyp(2)=py5(ip2)
            pzp(2)=pz5(ip2)
            pep(2)=e5(ip2)
            pmp(2)=xmass5(ip2)

c           Calculate distances
            call czcoal_locldr_bmcomp(2,1,2)
            dr0=drlocl

c           Check momentum constraint
            dp0=dsqrt(2*(pep(1)*pep(2)-pxp(1)*pxp(2)
     &           -pyp(1)*pyp(2)-pzp(1)*pzp(2)-pmp(1)*pmp(2)))
            if(dp0.gt.dpcoal) goto 120

c           Update best meson candidate
            if(dr0.lt.dr0m) then
               dr0m=dr0
               ip2m=ip2
            endif
 120     continue

c        Find best baryon partners
         ip2b0=0
         do 130 ip2=ip1+1,mul
            if(IOVER(ip2).eq.1) goto 130
c           Check if same charge (baryon condition)
            if((ITYP5(ip1)*ITYP5(ip2)).lt.0) goto 130

c           Load second parton
            gxp(2)=gx5(ip2)
            gyp(2)=gy5(ip2)
            gzp(2)=gz5(ip2)
            ftp(2)=ft5(ip2)
            pxp(2)=px5(ip2)
            pyp(2)=py5(ip2)
            pzp(2)=pz5(ip2)
            pep(2)=e5(ip2)
            pmp(2)=xmass5(ip2)

c           Calculate distance
            call czcoal_locldr_bmcomp(2,1,2)
            dr0=drlocl
            if(dr0.ge.dr0b1.and.dr0.ge.dr0m) goto 130

c           Update best 2nd baryon partner
            if(dr0.lt.dr0b1) then
               dr0b1=dr0
               ip2b0=ip2
            endif
 130     continue

c        Decision logic
         if(ITYP5(ip1).gt.0.and.nq.eq.2.and.nqbar.gt.0) then
c           Only 2 quarks left and there are antiquarks - must form meson
            npmb=2
         elseif(ip2b0.eq.0) then
c           No baryon partner found
            npmb=2
         elseif(ip2b0.ne.0) then
c           Find third baryon partner and compete with meson
            gxp(2)=gx5(ip2b0)
            gyp(2)=gy5(ip2b0)
            gzp(2)=gz5(ip2b0)
            ftp(2)=ft5(ip2b0)
            pxp(2)=px5(ip2b0)
            pyp(2)=py5(ip2b0)
            pzp(2)=pz5(ip2b0)
            pep(2)=e5(ip2b0)
            pmp(2)=xmass5(ip2b0)

            drAvg0=drbig
            ip3b0=0
            do 140 ip3=ip1+1,mul
               if(IOVER(ip3).eq.1.or.(ITYP5(ip1)*ITYP5(ip3)).lt.0
     1            .or.ip3.eq.ip2b0) goto 140

               gxp(3)=gx5(ip3)
               gyp(3)=gy5(ip3)
               gzp(3)=gz5(ip3)
               ftp(3)=ft5(ip3)
               pxp(3)=px5(ip3)
               pyp(3)=py5(ip3)
               pzp(3)=pz5(ip3)
               pep(3)=e5(ip3)
               pmp(3)=xmass5(ip3)

c              Calculate 3-body distances
               call czcoal_locldr_bmcomp(3,0,0)
               drAvg=(drlo1+drlo2+drlo3)/3d0

               if(drAvg.lt.drAvg0) then
                  drAvg0=drAvg
                  ip3b0=ip3
               endif
 140        continue


c           B/M competition decision
            if(drAvg0.lt.drbig.and.dr0m.lt.drbig.and.ip2m.ne.0) then
               if(drAvg0.lt.(drbmRatio*dr0m)) then
                  npmb=3
               else
                  npmb=2
               endif
            elseif(drAvg0.lt.drbig.and.ip3b0.ne.0) then
               npmb=3
            elseif(dr0m.lt.drbig.and.ip2m.ne.0) then
               npmb=2
            else
               write(6,*) 'error in coalescence for ip=',ip1,nq,nqbar
               stop
            endif
         endif

c        Form hadron
         isg=isg+1
         if(npmb.eq.2) then
c           Form meson
            IOVER(ip2m)=1
            call czcoal_setPtoH(isg,npmb,ip1,ip2m,0)
            nsmm1=nsmm1+1
            nq=nq-1
            nqbar=nqbar-1
         elseif(npmb.eq.3) then
c           Form baryon
            IOVER(ip2b0)=1
            IOVER(ip3b0)=1
            call czcoal_setPtoH(isg,npmb,ip1,ip2b0,ip3b0)
            if(ITYP5(ip1).gt.0) then
               nsmb1=nsmb1+1
               nq=nq-3
c              Debug output for baryon formation
               if(ITYP5(ip1).le.0.or.ITYP5(ip2b0).le.0.or.
     1            ITYP5(ip3b0).le.0) then
                  write(6,*) 'ERROR: baryon from mixed quarks:',
     1               ITYP5(ip1),ITYP5(ip2b0),ITYP5(ip3b0)
               endif
            else
               nsmab1=nsmab1+1
               nqbar=nqbar-3
c              Debug check for antibaryon formation
               if(ITYP5(ip1).ge.0.or.ITYP5(ip2b0).ge.0.or.
     1            ITYP5(ip3b0).ge.0) then
                  write(6,*) 'ERROR: antibaryon from mixed quarks:',
     1               ITYP5(ip1),ITYP5(ip2b0),ITYP5(ip3b0)
               endif
            endif
         endif

 350  continue

      NSG=isg
c     Removed: individual method output now handled in CZCOAL_MAIN

      RETURN
      END

c-----------------------------------------------------------------------
      SUBROUTINE czcoal_parORD()
c
c     Sort partons by freeze-out time (simple bubble sort)
c
      implicit double precision (a-h, o-z)
      PARAMETER (MAXPTN=400001)
      DOUBLE PRECISION  GX5, GY5, GZ5, FT5, PX5, PY5, PZ5, E5, XMASS5
      DOUBLE PRECISION  temp
      integer itemp,ITYP5
      COMMON /prec2/GX5(MAXPTN),GY5(MAXPTN),GZ5(MAXPTN),FT5(MAXPTN),
     &     PX5(MAXPTN), PY5(MAXPTN), PZ5(MAXPTN), E5(MAXPTN),
     &     XMASS5(MAXPTN), ITYP5(MAXPTN)
      COMMON /PARA1/ MUL
      SAVE

c     Simple bubble sort by FT5 (freeze-out time)
      do i=1,MUL-1
         do j=i+1,MUL
            if(FT5(j).lt.FT5(i)) then
c              Swap all properties
               temp=GX5(i)
               GX5(i)=GX5(j)
               GX5(j)=temp

               temp=GY5(i)
               GY5(i)=GY5(j)
               GY5(j)=temp

               temp=GZ5(i)
               GZ5(i)=GZ5(j)
               GZ5(j)=temp

               temp=FT5(i)
               FT5(i)=FT5(j)
               FT5(j)=temp

               temp=PX5(i)
               PX5(i)=PX5(j)
               PX5(j)=temp

               temp=PY5(i)
               PY5(i)=PY5(j)
               PY5(j)=temp

               temp=PZ5(i)
               PZ5(i)=PZ5(j)
               PZ5(j)=temp

               temp=E5(i)
               E5(i)=E5(j)
               E5(j)=temp

               temp=XMASS5(i)
               XMASS5(i)=XMASS5(j)
               XMASS5(j)=temp

               itemp=ITYP5(i)
               ITYP5(i)=ITYP5(j)
               ITYP5(j)=itemp
            endif
         enddo
      enddo

      RETURN
      END

c-----------------------------------------------------------------------
      SUBROUTINE czcoal_locldr_bmcomp(icall,i1,i2)
c
c     Calculate relative distances for B/M competition algorithm
c
      implicit double precision (a-h, o-z)
      dimension ftp0(3),pxp0(3),pyp0(3),pzp0(3),pep0(3)
      common /loclco/gxp(3),gyp(3),gzp(3),ftp(3),
     1     pxp(3),pyp(3),pzp(3),pep(3),pmp(3)
      common /prtn23/ gxp0(3),gyp0(3),gzp0(3),ft0fom,drlocl,drlot,
     1     drlo1,drlo2,drlo3,drlo1t,drlo2t,drlo3t
      common /lor/ enenew, pxnew, pynew, pznew
      SAVE

c     2-body distance calculation
      if(icall.eq.2) then
         etot=pep(i1)+pep(i2)
         bex=(pxp(i1)+pxp(i2))/etot
         bey=(pyp(i1)+pyp(i2))/etot
         bez=(pzp(i1)+pzp(i2))/etot

c        Boost to pair rest frame
         do j=1,2
            if(j.eq.1) then
               i=i1
            else
               i=i2
            endif
            call lorenz(ftp(i),gxp(i),gyp(i),gzp(i),bex,bey,bez)
            gxp0(j)=pxnew
            gyp0(j)=pynew
            gzp0(j)=pznew
            ftp0(j)=enenew
            call lorenz(pep(i),pxp(i),pyp(i),pzp(i),bex,bey,bez)
            pxp0(j)=pxnew
            pyp0(j)=pynew
            pzp0(j)=pznew
            pep0(j)=enenew
         enddo

c        Calculate relative distance
         if(ftp0(1).ge.ftp0(2)) then
            ilate=1
            iearly=2
         else
            ilate=2
            iearly=1
         endif

         dt0=ftp0(ilate)-ftp0(iearly)
         gxp0(iearly)=gxp0(iearly)+pxp0(iearly)/pep0(iearly)*dt0
         gyp0(iearly)=gyp0(iearly)+pyp0(iearly)/pep0(iearly)*dt0
         gzp0(iearly)=gzp0(iearly)+pzp0(iearly)/pep0(iearly)*dt0

         drlocl=dsqrt((gxp0(ilate)-gxp0(iearly))**2
     1        +(gyp0(ilate)-gyp0(iearly))**2
     2        +(gzp0(ilate)-gzp0(iearly))**2)

c     3-body distance calculation
      elseif(icall.eq.3) then
         etot=pep(1)+pep(2)+pep(3)
         bex=(pxp(1)+pxp(2)+pxp(3))/etot
         bey=(pyp(1)+pyp(2)+pyp(3))/etot
         bez=(pzp(1)+pzp(2)+pzp(3))/etot

c        Boost to 3-parton rest frame
         do j=1,3
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
         enddo

c        Find latest time
         ft0fom=max(ftp0(1),ftp0(2),ftp0(3))

c        Propagate all to latest time and calculate pairwise distances
         do i=1,3
            dt0=ft0fom-ftp0(i)
            gxp0(i)=gxp0(i)+pxp0(i)/pep0(i)*dt0
            gyp0(i)=gyp0(i)+pyp0(i)/pep0(i)*dt0
            gzp0(i)=gzp0(i)+pzp0(i)/pep0(i)*dt0
         enddo

         drlo1=dsqrt((gxp0(1)-gxp0(2))**2+(gyp0(1)-gyp0(2))**2
     &              +(gzp0(1)-gzp0(2))**2)
         drlo2=dsqrt((gxp0(1)-gxp0(3))**2+(gyp0(1)-gyp0(3))**2
     &              +(gzp0(1)-gzp0(3))**2)
         drlo3=dsqrt((gxp0(2)-gxp0(3))**2+(gyp0(2)-gyp0(3))**2
     &              +(gzp0(2)-gzp0(3))**2)
      endif

      RETURN
      END

c-----------------------------------------------------------------------
c     Shared utility functions
c-----------------------------------------------------------------------
      SUBROUTINE CZCOAL_LOCLDR(icall,drlocl_out)
c
      implicit double precision (a-h, o-z)
      dimension ftp0(3),pxp0(3),pyp0(3),pzp0(3),pep0(3)
      common /loclco/gxp(3),gyp(3),gzp(3),ftp(3),
     1     pxp(3),pyp(3),pzp(3),pep(3),pmp(3)
      common /prtn23/ gxp0(3),gyp0(3),gzp0(3),ft0fom,drlocl,drlot,
     1     drlo1,drlo2,drlo3,drlo1t,drlo2t,drlo3t
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

c-----------------------------------------------------------------------
c     Method 3: Random coalescence (no distance criteria)
c-----------------------------------------------------------------------
      SUBROUTINE CZCOAL_RANDOM()
c
      PARAMETER (MAXSTR=150001, MAXPTN=400001)
      implicit double precision (a-h, o-z)
      REAL HIPR1, HINT1
      DOUBLE PRECISION  PXSGS,PYSGS,PZSGS,PESGS,PMSGS,
     1     GXSGS,GYSGS,GZSGS,FTSGS
      INTEGER  K1SGS,K2SGS,NJSGS,NSG
      double precision  dpcoal,drcoal,ecritl,drbmRatio,mesonBaryonRatio
      integer icoal_method
      DOUBLE PRECISION  GX5, GY5, GZ5, FT5, PX5, PY5, PZ5, E5, XMASS5
      INTEGER ITYP5, IORDER(MAXPTN), nq, nqbar
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      COMMON/HJJET2/NSG
      COMMON /prec2/GX5(MAXPTN),GY5(MAXPTN),GZ5(MAXPTN),FT5(MAXPTN),
     &     PX5(MAXPTN), PY5(MAXPTN), PZ5(MAXPTN), E5(MAXPTN),
     &     XMASS5(MAXPTN), ITYP5(MAXPTN)
      COMMON /PARA1/ MUL
      COMMON /HPARNT/HIPR1(100), IHPR2(50), HINT1(100), IHNT2(50)
      common /czcoal_params/dpcoal,drcoal,ecritl,drbmRatio,
     1     mesonBaryonRatio,icoal_method
      SAVE /HPARNT/

c     Note: Energy conservation will be checked after coalescence
c     Removed: individual method output now handled in CZCOAL_MAIN

c     Convert /SOFT/ format to /prec2/ format
      call czcoal_soft_to_prec2(nq, nqbar)

c     Randomly shuffle parton order
      call czcoal_shuffle(IORDER, MUL)

c     Perform random coalescence with meson/baryon ratio control
      call czcoal_random_core(IORDER, nq, nqbar, isg_final)

c     No need to convert back - algorithm already writes to /SOFT/

      NSG=isg_final

c     Random coalescence completed

      return
      end

c-----------------------------------------------------------------------
      SUBROUTINE czcoal_shuffle(IORDER, N)
c
c     Randomly shuffle parton indices using Fisher-Yates algorithm
c
      implicit double precision (a-h, o-z)
      INTEGER IORDER(*), N, i, j, temp
      real rand_temp
      SAVE

c     Initialize order array
      do i=1,N
         IORDER(i) = i
      enddo

c     Fisher-Yates shuffle
      do i=N,2,-1
         call random_number(rand_temp)
         j = int(rand_temp*real(i)) + 1
         if(j.gt.i) j = i
         if(j.lt.1) j = 1
         temp = IORDER(i)
         IORDER(i) = IORDER(j)
         IORDER(j) = temp
      enddo
c     write(6,*) 'DEBUG: Shuffled',N,'partons'

      return
      end

c-----------------------------------------------------------------------
      SUBROUTINE czcoal_random_core(IORDER, nq_in, nqbar_in, isg_final)
c
c     Core random coalescence algorithm with meson/baryon ratio control
c
      PARAMETER (MAXSTR=150001, MAXPTN=400001)
      implicit double precision (a-h, o-z)
      INTEGER IORDER(*), IUSED(MAXPTN)
      INTEGER K1SGS,K2SGS,NJSGS,NSG,ITYP5
      DOUBLE PRECISION GX5, GY5, GZ5, FT5, PX5, PY5, PZ5, E5, XMASS5
      double precision dpcoal,drcoal,ecritl,drbmRatio,mesonBaryonRatio
      integer icoal_method,nq,nqbar,nused,isg,nq_orig,nqbar_orig
      integer nmeson,nbaryon,nantibaryon,isg_final,nq_in,nqbar_in
      integer nq_used,nqbar_used
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      COMMON/HJJET2/NSG
      COMMON /prec2/GX5(MAXPTN),GY5(MAXPTN),GZ5(MAXPTN),FT5(MAXPTN),
     &     PX5(MAXPTN), PY5(MAXPTN), PZ5(MAXPTN), E5(MAXPTN),
     &     XMASS5(MAXPTN), ITYP5(MAXPTN)
      COMMON /PARA1/ MUL
      common /czcoal_params/dpcoal,drcoal,ecritl,drbmRatio,
     1     mesonBaryonRatio,icoal_method
      SAVE

c     Initialize
      do i=1,MUL
         IUSED(i) = 0
      enddo
      nused = 0
      isg = 0
      nq = nq_in
      nqbar = nqbar_in
      nq_orig = nq
      nqbar_orig = nqbar
      nmeson = 0
      nbaryon = 0
      nantibaryon = 0

c     Main coalescence loop - process in random order
      do ip=1,MUL
         if(IUSED(IORDER(ip)).eq.1) goto 100

c        Mark first parton as used
         IUSED(IORDER(ip)) = 1
         nused = nused + 1

c        Try to form hadron starting with this parton
         call czcoal_form_hadron(IORDER(ip), IORDER, IUSED,
     1        nused, isg, nmeson, nbaryon, nantibaryon, nq, nqbar)

 100     continue
      enddo

c     Add remaining quarks as single-quark "hadrons"
      call czcoal_add_remaining_quarks(IORDER, IUSED, isg)

      NSG = isg
      isg_final = isg

c     Removed: individual method output now handled in CZCOAL_MAIN
      nq_used = nmeson + nbaryon*3
      nqbar_used = nmeson + nantibaryon*3

      return
      end

c-----------------------------------------------------------------------
      SUBROUTINE czcoal_add_remaining_quarks(IORDER, IUSED, isg)
c
c     Add remaining unused quarks back to /SOFT/ as single particles
c
      PARAMETER (MAXSTR=150001, MAXPTN=400001)
      implicit double precision (a-h, o-z)
      INTEGER IORDER(*), IUSED(*), isg, ITYP5
      DOUBLE PRECISION GX5, GY5, GZ5, FT5, PX5, PY5, PZ5, E5, XMASS5
      INTEGER K1SGS,K2SGS,NJSGS,NSG
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      COMMON /prec2/GX5(MAXPTN),GY5(MAXPTN),GZ5(MAXPTN),FT5(MAXPTN),
     &     PX5(MAXPTN), PY5(MAXPTN), PZ5(MAXPTN), E5(MAXPTN),
     &     XMASS5(MAXPTN), ITYP5(MAXPTN)
      COMMON /PARA1/ MUL
      SAVE

c     Add each unused quark as a single-particle "hadron"
      do i=1,MUL
         if(IUSED(IORDER(i)).eq.0) then
            isg = isg + 1
            call czcoal_setPtoH(isg, 1, IORDER(i), 0, 0)
         endif
      enddo

      return
      end

c-----------------------------------------------------------------------
      SUBROUTINE czcoal_form_hadron(ip1, IORDER, IUSED, nused, isg,
     1     nmeson, nbaryon, nantibaryon, nq, nqbar)
c
c     Form hadron starting with parton ip1
c
      PARAMETER (MAXSTR=150001, MAXPTN=400001)
      implicit double precision (a-h, o-z)
      INTEGER IORDER(*), IUSED(*), ip1, ip2, ip3, nused, isg
      INTEGER nmeson, nbaryon, nantibaryon, nq, nqbar
      INTEGER ITYP5, K1SGS, K2SGS, NJSGS, NSG
      DOUBLE PRECISION GX5, GY5, GZ5, FT5, PX5, PY5, PZ5, E5, XMASS5
      double precision dpcoal,drcoal,ecritl,drbmRatio,mesonBaryonRatio
      double precision rand_val
      integer icoal_method
      logical found_partner
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      COMMON/HJJET2/NSG
      COMMON /prec2/GX5(MAXPTN),GY5(MAXPTN),GZ5(MAXPTN),FT5(MAXPTN),
     &     PX5(MAXPTN), PY5(MAXPTN), PZ5(MAXPTN), E5(MAXPTN),
     &     XMASS5(MAXPTN), ITYP5(MAXPTN)
      COMMON /PARA1/ MUL
      common /czcoal_params/dpcoal,drcoal,ecritl,drbmRatio,
     1     mesonBaryonRatio,icoal_method
      SAVE

c     Decide meson vs baryon based on mesonBaryonRatio
c     Use a simple alternative random number generator for testing
      call random_number(rand_val)
c      DEBUG output removed: parton decision logging
      if(rand_val.lt.mesonBaryonRatio) then
c        Try to form meson
         call czcoal_find_meson_partner(ip1, IORDER, IUSED,
     1        ip2, found_partner)
         if(found_partner) then
            IUSED(ip2) = 1
            nused = nused + 1
            isg = isg + 1
            call czcoal_setPtoH(isg, 2, ip1, ip2, 0)
            nmeson = nmeson + 1
c           Update quark counts for meson formation
            nq = nq - 1
            nqbar = nqbar - 1
c            if(mod(nmeson,1000).eq.0) then
c               write(6,*) 'DEBUG: Formed',nmeson,'mesons so far'
c            endif
         else
c            DEBUG output removed: No meson partner found for parton
         endif
      else
c        Try to form baryon
         call czcoal_find_baryon_partners(ip1, IORDER, IUSED,
     1        ip2, ip3, found_partner)
         if(found_partner) then
            IUSED(ip2) = 1
            IUSED(ip3) = 1
            nused = nused + 2
            isg = isg + 1
            call czcoal_setPtoH(isg, 3, ip1, ip2, ip3)
c           Count baryon or antibaryon based on first parton type
            if(ITYP5(ip1).gt.0) then
               nbaryon = nbaryon + 1
               nq = nq - 3
            else
               nantibaryon = nantibaryon + 1
               nqbar = nqbar - 3
            endif
c            DEBUG output removed: Formed baryon
         else
c            DEBUG output removed: No baryon partners found
         endif
      endif

      return
      end

c-----------------------------------------------------------------------
      SUBROUTINE czcoal_get_method(icoal_method_out)
c
c     Get current coalescence method for external queries
c
      implicit double precision (a-h, o-z)
      double precision dpcoal,drcoal,ecritl,drbmRatio,mesonBaryonRatio
      integer icoal_method,icoal_method_out
      common /czcoal_params/dpcoal,drcoal,ecritl,drbmRatio,
     1     mesonBaryonRatio,icoal_method
      
      icoal_method_out = icoal_method
      
      return
      end

c-----------------------------------------------------------------------
      SUBROUTINE czcoal_count_initial(nq_init,nqbar_init)
c
c     Count initial quarks and antiquarks before coalescence
c
      PARAMETER (MAXSTR=150001)
      implicit double precision (a-h, o-z)
      INTEGER  K1SGS,K2SGS,NJSGS,NSG
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      COMMON/HJJET2/NSG
      SAVE

      nq_init = 0
      nqbar_init = 0

      do isg=1,NSG
         if(NJSGS(isg).eq.0) cycle
         do ip=1,NJSGS(isg)
            if(K2SGS(isg,ip).gt.0) then
               nq_init = nq_init + 1
            else
               nqbar_init = nqbar_init + 1
            endif
         enddo
      enddo

      return
      end

c-----------------------------------------------------------------------
      SUBROUTINE czcoal_count_final(nq_final,nqbar_final,
     &     nmeson,nbaryon,nantibaryon)
c
c     Count final state after coalescence
c
      PARAMETER (MAXSTR=150001)
      implicit double precision (a-h, o-z)
      INTEGER  K1SGS,K2SGS,NJSGS,NSG
      COMMON/SOFT/PXSGS(MAXSTR,3),PYSGS(MAXSTR,3),PZSGS(MAXSTR,3),
     &     PESGS(MAXSTR,3),PMSGS(MAXSTR,3),GXSGS(MAXSTR,3),
     &     GYSGS(MAXSTR,3),GZSGS(MAXSTR,3),FTSGS(MAXSTR,3),
     &     K1SGS(MAXSTR,3),K2SGS(MAXSTR,3),NJSGS(MAXSTR)
      COMMON/HJJET2/NSG
      SAVE

      nq_final = 0
      nqbar_final = 0
      nmeson = 0
      nbaryon = 0
      nantibaryon = 0

      do isg=1,NSG
         if(NJSGS(isg).eq.0) cycle
         
         if(NJSGS(isg).eq.1) then
c           Single parton (not coalesced)
            if(K2SGS(isg,1).gt.0) then
               nq_final = nq_final + 1
            else
               nqbar_final = nqbar_final + 1
            endif
         elseif(NJSGS(isg).eq.2) then
c           Meson
            nmeson = nmeson + 1
         elseif(NJSGS(isg).eq.3) then
c           Baryon or antibaryon
            if(K2SGS(isg,1).gt.0) then
               nbaryon = nbaryon + 1
            else
               nantibaryon = nantibaryon + 1
            endif
         endif
      enddo

      return
      end

c-----------------------------------------------------------------------
      SUBROUTINE czcoal_find_meson_partner(ip1, IORDER, IUSED,
     1     ip2, found_partner)
c
c     Find partner for meson formation
c
      PARAMETER (MAXPTN=400001)
      implicit double precision (a-h, o-z)
      INTEGER IORDER(*), IUSED(*), ip1, ip2, ITYP5
      logical found_partner
      COMMON /prec2/GX5(MAXPTN),GY5(MAXPTN),GZ5(MAXPTN),FT5(MAXPTN),
     &     PX5(MAXPTN), PY5(MAXPTN), PZ5(MAXPTN), E5(MAXPTN),
     &     XMASS5(MAXPTN), ITYP5(MAXPTN)
      COMMON /PARA1/ MUL
      SAVE

      found_partner = .false.
      ip2 = 0

c     Look for opposite charge partner in random order
      do i=1,MUL
         if(IUSED(IORDER(i)).eq.1) goto 10
         if(IORDER(i).eq.ip1) goto 10

c        Check if opposite charge (meson condition)
         if((ITYP5(ip1)*ITYP5(IORDER(i))).lt.0) then
            ip2 = IORDER(i)
            found_partner = .true.
            return
         endif

 10      continue
      enddo

      return
      end

c-----------------------------------------------------------------------
      SUBROUTINE czcoal_find_baryon_partners(ip1, IORDER, IUSED,
     1     ip2, ip3, found_partner)
c
c     Find two partners for baryon formation
c
      PARAMETER (MAXPTN=400001)
      implicit double precision (a-h, o-z)
      INTEGER IORDER(*), IUSED(*), ip1, ip2, ip3, ITYP5
      logical found_partner
      COMMON /prec2/GX5(MAXPTN),GY5(MAXPTN),GZ5(MAXPTN),FT5(MAXPTN),
     &     PX5(MAXPTN), PY5(MAXPTN), PZ5(MAXPTN), E5(MAXPTN),
     &     XMASS5(MAXPTN), ITYP5(MAXPTN)
      COMMON /PARA1/ MUL
      SAVE

      found_partner = .false.
      ip2 = 0
      ip3 = 0

c     Look for two same-charge partners
      do i=1,MUL
         if(IUSED(IORDER(i)).eq.1) goto 20
         if(IORDER(i).eq.ip1) goto 20

c        Check if same charge (baryon condition)
         if((ITYP5(ip1)*ITYP5(IORDER(i))).gt.0) then
            if(ip2.eq.0) then
               ip2 = IORDER(i)
            else
               ip3 = IORDER(i)
               found_partner = .true.
               return
            endif
         endif

 20      continue
      enddo

      return
      end
