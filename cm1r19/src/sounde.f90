  MODULE sounde_module

  implicit none

  private
  public :: sounde

  CONTAINS

      subroutine sounde(dt,xh,arh1,arh2,uh,ruh,xf,uf,yh,vh,rvh,yf,vf,     &
                        rds,sigma,rdsf,sigmaf,zh,mh,rmh,c1,c2,mf,zf,      &
                        pi0,rho0,rr0,rf0,rrf0,th0,rth0,zs,                &
                        gz,rgz,gzu,rgzu,gzv,rgzv,                         &
                        dzdx,dzdy,gx,gxu,gy,gyv,                          &
                        radbcw,radbce,radbcs,radbcn,                      &
                        dum1,dum2,dum3,dum4,dum5,dum6,                    &
                        ppd ,fpk ,qk ,pk1,pk2,ftk,                        &
                        u0,rru,ua,u3d,uten,                               &
                        v0,rrv,va,v3d,vten,                               &
                        rrw,wa,w3d,wten,                                  &
                        ppi,pp3d,piadv,ppten,ppx,                         &
                        thv,ppterm,nrk,dttmp,rtime,mtime,get_time_avg,    &
                        pw1,pw2,pe1,pe2,ps1,ps2,pn1,pn2,reqs_p)
      use input
      use constants
      use misclibs , only : convinitu,convinitv,get_wnudge
      use bc_module
      use comm_module
      implicit none

      real, intent(in) :: dt
      real, intent(in), dimension(ib:ie) :: xh,arh1,arh2,uh,ruh
      real, intent(in), dimension(ib:ie+1) :: xf,uf
      real, intent(in), dimension(jb:je) :: yh,vh,rvh
      real, intent(in), dimension(jb:je+1) :: yf,vf
      real, intent(in), dimension(kb:ke) :: rds,sigma
      real, intent(in), dimension(kb:ke+1) :: rdsf,sigmaf
      real, intent(in), dimension(ib:ie,jb:je,kb:ke) :: zh,mh,rmh,c1,c2
      real, intent(in), dimension(ib:ie,jb:je,kb:ke+1) :: mf,zf
      real, intent(in), dimension(ib:ie,jb:je,kb:ke) :: pi0,rho0,rr0,rf0,rrf0,th0,rth0
      real, intent(in), dimension(ib:ie,jb:je) :: zs
      real, intent(in), dimension(itb:ite,jtb:jte) :: gz,rgz,gzu,rgzu,gzv,rgzv,dzdx,dzdy
      real, intent(in), dimension(itb:ite,jtb:jte,ktb:kte) :: gx,gxu,gy,gyv
      real, intent(inout), dimension(jb:je,kb:ke) :: radbcw,radbce
      real, intent(inout), dimension(ib:ie,kb:ke) :: radbcs,radbcn
      real, intent(inout), dimension(ib:ie,jb:je,kb:ke) :: dum1,dum2,dum3,dum4,dum5,dum6
      real, intent(inout), dimension(ib:ie,jb:je,kb:ke) :: ppd,fpk,qk,pk1,pk2,ftk
      real, intent(in), dimension(ib:ie+1,jb:je,kb:ke) :: u0
      real, intent(inout), dimension(ib:ie+1,jb:je,kb:ke) :: rru,ua,u3d,uten
      real, intent(in), dimension(ib:ie,jb:je+1,kb:ke) :: v0
      real, intent(inout), dimension(ib:ie,jb:je+1,kb:ke) :: rrv,va,v3d,vten
      real, intent(inout), dimension(ib:ie,jb:je,kb:ke+1) :: rrw,wa,w3d,wten
      real, intent(inout), dimension(ib:ie,jb:je,kb:ke) :: ppi,pp3d,piadv,ppten,ppx
      real, intent(in), dimension(ib:ie,jb:je,kb:ke) :: thv,ppterm
      integer, intent(in) :: nrk
      real, intent(in)  :: dttmp,rtime
      double precision, intent(in) :: mtime
      logical, intent(in) :: get_time_avg
      real, intent(inout), dimension(jmp,kmp) :: pw1,pw2,pe1,pe2
      real, intent(inout), dimension(imp,kmp) :: ps1,ps2,pn1,pn2
      integer, intent(inout), dimension(rmp) :: reqs_p

!-----

      integer :: i,j,k,n,nloop
      real :: tem,tem1,tem2,tem3,tem4,r1,r2,dts

      real :: temx,temy,u1,u2,v1,v2,w1,w2,ww,div,tavg

!---------------------------------------------------------------------

    IF( nrkmax.eq.3 )THEN
      if(nrk.eq.1)then
!!!        nloop=1
!!!        dts=dt/3.
        nloop=nint(float(nsound)/3.0)
        dts=dt/(nloop*3.0)
        if( dts.gt.(dt/nsound) )then
          nloop=nloop+1
          dts=dt/(nloop*3.0)
        endif
      elseif(nrk.eq.2)then
        nloop=0.5*nsound
        dts=dt/nsound
      elseif(nrk.eq.3)then
        nloop=nsound
        dts=dt/nsound
      endif
    ELSE
      stop 97393
    ENDIF

!!!      print *,'  nloop,dts,dttmp = ',nloop,dts,nloop*dts

!---------------------------------------------------------------------
!  Arrays for vadv:

      IF(.not.terrain_flag)THEN

        ! without terrain:
        ! "s" velocities ARE NOT coupled with reference density
!$omp parallel do default(shared)   &
!$omp private(i,j,k,tem,tem1,r1,r2)
        do k=1,nk
          r2 = dts*rdz*mh(1,1,k)*rr0(1,1,k)*rf0(1,1,k+1)
          r1 = dts*rdz*mh(1,1,k)*rr0(1,1,k)*rf0(1,1,k)
          do j=1,nj
          do i=1,ni
            pk2(i,j,k) = r2*( -c2(1,1,k+1)*piadv(i,j,k+1)+(1.0-c1(1,1,k+1))*piadv(i,j,k) )
            pk1(i,j,k) = r1*( +c1(1,1,k  )*piadv(i,j,k-1)+(c2(1,1,k  )-1.0)*piadv(i,j,k) )
          enddo
          enddo
        enddo

      ELSE

        ! with terrain:
        ! "s" velocities ARE coupled with reference density
!$omp parallel do default(shared)   &
!$omp private(i,j,k,tem,tem1,tem2,r1,r2)
        do k=1,nk
          do j=1,nj
          do i=1,ni
            tem2 = dts*gz(i,j)*rdsf(k)*rr0(i,j,k)
            pk2(i,j,k) = tem2*rf0(i,j,k+1)*( -c2(i,j,k+1)*piadv(i,j,k+1)+(1.0-c1(i,j,k+1))*piadv(i,j,k) )
            pk1(i,j,k) = tem2*rf0(i,j,k+1)*( +c1(i,j,k  )*piadv(i,j,k-1)+(c2(i,j,k  )-1.0)*piadv(i,j,k) )
          enddo
          enddo
          IF( k.eq.1 )THEN
            do j=1,nj
            do i=1,ni
              dum3(i,j,1)=0.0
              dum3(i,j,nk+1)=0.0
            enddo
            enddo
          ENDIF
        enddo

      ENDIF

!$omp parallel do default(shared)   &
!$omp private(i,j)
      do j=1,nj
      do i=1,ni
        pk1(i,j,1) = 0.0
        pk2(i,j,nk) = 0.0
      enddo
      enddo

!---------------------------------------------------------------------
!  Prepare for acoustic steps

      if( nrk.eq.1 )then

        !$omp parallel do default(shared)   &
        !$omp private(i,j,k)
        do k=1,nk
        do j=0,nj+1
        do i=0,ni+1
          ppd(i,j,k)=ppx(i,j,k)
        enddo
        enddo
        enddo

      else

!$omp parallel do default(shared)   &
!$omp private(i,j,k)
        do k=1,nk
          do j=1,nj
          do i=1,ni+1
            u3d(i,j,k)=ua(i,j,k)
          enddo
          enddo
          IF(axisymm.eq.0)THEN
            ! Cartesian grid:
            do j=1,nj+1
            do i=1,ni
              v3d(i,j,k)=va(i,j,k)
            enddo
            enddo
          ENDIF
          IF(k.ge.2)THEN
            do j=1,nj
            do i=1,ni
              w3d(i,j,k)=wa(i,j,k)
            enddo
            enddo
          ENDIF
          do j=1,nj
          do i=1,ni
            pp3d(i,j,k)=ppi(i,j,k)
          enddo
          enddo
          do j=0,nj+1
          do i=0,ni+1
            ppd(i,j,k)=ppx(i,j,k)
          enddo
          enddo
        enddo

      endif

!---------------------------------------------------------------------
!  time-averaged velocities:

      IF( get_time_avg )THEN
!$omp parallel do default(shared)   &
!$omp private(i,j,k)
        DO k=1,nk
          do j=1,nj
          do i=1,ni+1
            rru(i,j,k)=0.0
          enddo
          enddo
          IF(axisymm.eq.0)THEN
            do j=1,nj+1
            do i=1,ni
              rrv(i,j,k)=0.0
            enddo
            enddo
          ENDIF
          IF(k.ge.2)THEN
            do j=1,nj
            do i=1,ni
              rrw(i,j,k)=0.0
            enddo
            enddo
          ENDIF
        ENDDO
      ENDIF
      if(timestats.ge.1) time_sound=time_sound+mytime()

!-----------------------------------------------------------------------
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!-----------------------------------------------------------------------
!  Begin small steps:

      small_step_loop:  DO N=1,NLOOP

!-----

        if(irbc.eq.2)then
 
          if(ibw.eq.1 .or. ibe.eq.1) call radbcew(radbcw,radbce,u3d)
 
          if(ibs.eq.1 .or. ibn.eq.1) call radbcns(radbcs,radbcn,v3d)
 
        endif

!-----------------------------------------------------------------------
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!-----------------------------------------------------------------------
!  Open boundary conditions:

        IF(wbc.eq.2.and.ibw.eq.1)THEN
          ! west open bc tendency:
          call   ssopenbcw(uh,rds,sigma,rdsf,sigmaf,gz,rgzu,gx,radbcw,dum1,u3d,uten,dts)
        ENDIF
        IF(ebc.eq.2.and.ibe.eq.1)THEN
          ! east open bc tendency:
          call   ssopenbce(uh,rds,sigma,rdsf,sigmaf,gz,rgzu,gx,radbce,dum1,u3d,uten,dts)
        ENDIF

        IF(roflux.eq.1)THEN
          call restrict_openbc_we(rvh,rmh,rho0,u3d)
        ENDIF

!-----

      IF(axisymm.eq.0)THEN
        IF(sbc.eq.2.and.ibs.eq.1)THEN
          ! south open bc tendency:
          call   ssopenbcs(vh,rds,sigma,rdsf,sigmaf,gz,rgzv,gy,radbcs,dum1,v3d,vten,dts)
        ENDIF
        IF(nbc.eq.2.and.ibn.eq.1)THEN
          ! north open bc tendency:
          call   ssopenbcn(vh,rds,sigma,rdsf,sigmaf,gz,rgzv,gy,radbcn,dum1,v3d,vten,dts)
        ENDIF

        IF(roflux.eq.1)THEN
          call restrict_openbc_sn(ruh,rmh,rho0,v3d)
        ENDIF
      ENDIF

!-----------------------------------------------------------------------
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!-----------------------------------------------------------------------
!  integrate u,v forward in time:

        if( n.ne.1 )then
          if(timestats.ge.1) time_sound=time_sound+mytime()
          call comm_1p_end(ppd,pw1,pw2,pe1,pe2,   &
                               ps1,ps2,pn1,pn2,reqs_p)
        endif

!-----

    IF(.not.terrain_flag)THEN

      IF(axisymm.eq.0)THEN
        ! Cartesian grid without terrain:

        tem1 = rdx*cp*0.5
        tem2 = rdy*cp*0.5
!$omp parallel do default(shared)   &
!$omp private(i,j,k)
        do k=1,nk
          do j=1,nj
          do i=1+ibw,ni+1-ibe
            u3d(i,j,k)=u3d(i,j,k)+dts*( uten(i,j,k)         &
                   -tem1*(ppd(i,j,k)-ppd(i-1,j,k))*uf(i)    &
                        *(thv(i,j,k)+thv(i-1,j,k)) )
          enddo
          enddo
          do j=1+ibs,nj+1-ibn
          do i=1,ni
            v3d(i,j,k)=v3d(i,j,k)+dts*( vten(i,j,k)         &
                   -tem2*(ppd(i,j,k)-ppd(i,j-1,k))*vf(j)    &
                        *(thv(i,j,k)+thv(i,j-1,k)) )
          enddo
          enddo
        enddo

      ELSE
        ! axisymmetric grid:

        tem1 = rdx*cp*0.5
!$omp parallel do default(shared)   &
!$omp private(i,j,k)
        do k=1,nk
          do j=1,nj
          do i=1+ibw,ni+1-ibe
            u3d(i,j,k)=u3d(i,j,k)+dts*( uten(i,j,k)         &
                   -tem1*(ppd(i,j,k)-ppd(i-1,j,k))*uf(i)    &
                        *(thv(i,j,k)+thv(i-1,j,k)) )
          enddo
          enddo
        enddo

      ENDIF

    ELSE

        ! Cartesian grid with terrain:

!$omp parallel do default(shared)   &
!$omp private(i,j,k,r1,r2)
        do j=0,nj+1
          do k=2,nk
          do i=0,ni+1
            dum1(i,j,k) = (ppd(i,j,k)-ppd(i,j,k-1))*rds(k)
          enddo
          enddo
          do i=0,ni+1
            dum1(i,j,1) = 0.0
            dum1(i,j,nk+1) = 0.0
          enddo
        enddo

        tem = cp*0.5

!$omp parallel do default(shared)   &
!$omp private(i,j,k)
        do k=1,nk
          ! x-dir
          do j=1,nj
          do i=1+ibw,ni+1-ibe
            u3d(i,j,k)=u3d(i,j,k)+dts*( uten(i,j,k)         &
                   -tem*(thv(i,j,k)+thv(i-1,j,k))*(         &
                     (ppd(i,j,k)-ppd(i-1,j,k))*rdx*uf(i)    &
              +0.125*( (dum1(i,j,k+1)+dum1(i-1,j,k+1))      &
                      +(dum1(i,j,k  )+dum1(i-1,j,k  )) )    &
                    *(gxu(i,j,k)+gxu(i,j,k+1))    ) )
          enddo
          enddo
          do j=1+ibs,nj+1-ibn
          do i=1,ni
            v3d(i,j,k)=v3d(i,j,k)+dts*( vten(i,j,k)         &
                   -tem*(thv(i,j,k)+thv(i,j-1,k))*(         &
                     (ppd(i,j,k)-ppd(i,j-1,k))*rdy*vf(j)    &
              +0.125*( (dum1(i,j,k+1)+dum1(i,j-1,k+1))      &
                      +(dum1(i,j,k  )+dum1(i,j-1,k  )) )    &
                    *(gyv(i,j,k)+gyv(i,j,k+1))    ) )
          enddo
          enddo
        enddo


    ENDIF

!----------------------------------------------
!  convergence forcing:

        IF( convinit.eq.1 )THEN
          IF( rtime.le.convtime .and. nx.gt.1 )THEN
            call convinitu(myid,ib,ie,jb,je,kb,ke,ni,nj,nk,ibw,ibe,   &
                           zdeep,lamx,lamy,xcent,ycent,aconv,    &
                           xf,yh,zh,u0,u3d)
          ENDIF
        ENDIF

!----------------------------------------------

      IF(axisymm.eq.0)THEN
        ! Cartesian grid:

!----------------------------------------------
!  convergence forcing:

        IF( convinit.eq.1 )THEN
          IF( rtime.le.convtime .and. ny.gt.1 )THEN
            call convinitv(myid,ib,ie,jb,je,kb,ke,ni,nj,nk,ibs,ibn,   &
                           zdeep,lamx,lamy,xcent,ycent,aconv,    &
                           xh,yf,zh,v0,v3d)
          ENDIF
        ENDIF

!----------------------------------------------

      ENDIF

      if(timestats.ge.1) time_sound=time_sound+mytime()

!-----------------------------------------------------------------------
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!-----------------------------------------------------------------------
!  integrate w forward in time:


      IF( wnudge.eq.1 )THEN
        !  updraft nudging tendency:
        IF( (mtime+dt).le.t2_wnudge )THEN
          !$omp parallel do default(shared)   &
          !$omp private(i,j,k)
          do k=2,nk
          do j=1,nj
          do i=1,ni
            dum1(i,j,k)=0.0
          enddo
          enddo
          enddo
          call get_wnudge(mtime,dts,xh,yh,zf,w3d,dum1)
        ENDIF
      ENDIF


      IF(.not.terrain_flag)THEN
        ! without terrain:

!$omp parallel do default(shared)   &
!$omp private(i,j,k,tem1)
        do k=2,nk
        tem1 = rdz*cp*mf(1,1,k)
        do j=1,nj
        do i=1,ni
          w3d(i,j,k)=w3d(i,j,k)+dts*( wten(i,j,k)                     &
                  -tem1*(ppd(i,j,k)-ppd(i,j,k-1))                     &
                       *(c2(1,1,k)*thv(i,j,k)+c1(1,1,k)*thv(i,j,k-1)) )
        enddo
        enddo
        enddo

      ELSE
        ! with terrain:

!$omp parallel do default(shared)   &
!$omp private(i,j,k,tem1)
        do k=2,nk
        tem1 = rds(k)*cp
        do j=1,nj
        do i=1,ni
          w3d(i,j,k)=w3d(i,j,k)+dts*( wten(i,j,k)                     &
                  -tem1*(ppd(i,j,k)-ppd(i,j,k-1))*gz(i,j)             &
                       *(c2(i,j,k)*thv(i,j,k)+c1(i,j,k)*thv(i,j,k-1)) )
        enddo
        enddo
        enddo
        if(timestats.ge.1) time_sound=time_sound+mytime()

        call bcwsfc(gz,dzdx,dzdy,u3d,v3d,w3d)

      ENDIF


      IF( wnudge.eq.1 )THEN
        !  apply updraft nudging:
        IF( (mtime+dt).le.t2_wnudge )THEN
          !$omp parallel do default(shared)   &
          !$omp private(i,j,k)
          do k=2,nk
          do j=1,nj
          do i=1,ni
            w3d(i,j,k)=w3d(i,j,k)+dum1(i,j,k)
          enddo
          enddo
          enddo
        ENDIF
      ENDIF


!-----------------------------------------------------------------------
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!-----------------------------------------------------------------------
!  get terms for div,vadv (terrain only):

      IF(terrain_flag)THEN
        ! Cartesian grid with terrain:
!$omp parallel do default(shared)   &
!$omp private(i,j,k)
        DO k=1,nk
          do j=1,nj
          do i=1,ni+1
            dum1(i,j,k)=u3d(i,j,k)*rgzu(i,j)
            dum4(i,j,k)=0.5*(rho0(i-1,j,k)+rho0(i,j,k))*dum1(i,j,k)
          enddo
          enddo
          do j=1,nj+1
          do i=1,ni
            dum2(i,j,k)=v3d(i,j,k)*rgzv(i,j)
            dum5(i,j,k)=0.5*(rho0(i,j-1,k)+rho0(i,j,k))*dum2(i,j,k)
          enddo
          enddo
        ENDDO
!$omp parallel do default(shared)   &
!$omp private(i,j,k,r1,r2)
        DO k=2,nk
          r2 = (sigmaf(k)-sigma(k-1))*rds(k)
          r1 = 1.0-r2
          do j=1,nj
          do i=1,ni
            dum3(i,j,k)=w3d(i,j,k)                                               &
                       +0.5*( ( r2*(dum1(i,j,k  )+dum1(i+1,j,k  ))               &
                               +r1*(dum1(i,j,k-1)+dum1(i+1,j,k-1)) )*dzdx(i,j)   &
                             +( r2*(dum2(i,j,k  )+dum2(i,j+1,k  ))               &
                               +r1*(dum2(i,j,k-1)+dum2(i,j+1,k-1)) )*dzdy(i,j)   &
                            )*(sigmaf(k)-zt)*gz(i,j)*rzt
            ! do not couple dum6 with rho0:
            ! (note formulation of pk1,pk2)
            dum6(i,j,k)=w3d(i,j,k)                                               &
                       +0.5*( ( r2*(dum4(i,j,k  )+dum4(i+1,j,k  ))               &
                               +r1*(dum4(i,j,k-1)+dum4(i+1,j,k-1)) )*dzdx(i,j)   &
                             +( r2*(dum5(i,j,k  )+dum5(i,j+1,k  ))               &
                               +r1*(dum5(i,j,k-1)+dum5(i,j+1,k-1)) )*dzdy(i,j)   &
                            )*(sigmaf(k)-zt)*gz(i,j)*rzt * rrf0(i,j,k)
          enddo
          enddo
        ENDDO
      ENDIF

!-----------------------------------------------------------------------
!ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
!-----------------------------------------------------------------------
!  get new pp,th

      temx = dts*0.5*rdx
      temy = dts*0.5*rdy

    IF( axisymm.eq.0 )THEN

      IF(.not.terrain_flag)THEN
        ! Cartesian grid, without terrain:

        !$omp parallel do default(shared)   &
        !$omp private(i,j,k,div,u1,u2,v1,v2,w1,w2,tem)
        do k=1,nk
        do j=1,nj
        do i=1,ni
          div=( (u3d(i+1,j,k)-u3d(i,j,k))*rdx*uh(i)    &
               +(v3d(i,j+1,k)-v3d(i,j,k))*rdy*vh(j) )  &
               +(w3d(i,j,k+1)-w3d(i,j,k))*rdz*mh(1,1,k)
          if(abs(div).lt.smeps) div=0.0
          u2 = temx*u3d(i+1,j,k)*uh(i)
          u1 = temx*u3d(i  ,j,k)*uh(i)
          v2 = temy*v3d(i,j+1,k)*vh(j)
          v1 = temy*v3d(i,j  ,k)*vh(j)
          w2 = w3d(i,j,k+1)
          w1 = w3d(i,j,k  )
          !-----
          ppd(i,j,k)=pp3d(i,j,k)
          pp3d(i,j,k)=pp3d(i,j,k)+dts*( ppten(i,j,k)-ppterm(i,j,k)*div )  &
                 +( -( u2*(piadv(i+1,j,k)-piadv(i  ,j,k))                 &
                      +u1*(piadv(i  ,j,k)-piadv(i-1,j,k)) )               &
                    -( v2*(piadv(i,j+1,k)-piadv(i,j  ,k))                 &
                      +v1*(piadv(i,j  ,k)-piadv(i,j-1,k)) ) )             &
                    +( w1*pk1(i,j,k)+w2*pk2(i,j,k) )
          if(abs(pp3d(i,j,k)).lt.smeps) pp3d(i,j,k)=0.0
          dum1(i,j,k)=kdiv*( pp3d(i,j,k)-ppd(i,j,k) )
          ppd(i,j,k)=pp3d(i,j,k)+dum1(i,j,k)
          !-----
        enddo
        enddo
        enddo

      ELSE
        ! Cartesian grid, with terrain:

        !$omp parallel do default(shared)   &
        !$omp private(i,j,k,div,u1,u2,v1,v2,w1,w2,tem)
        do k=1,nk
        do j=1,nj
        do i=1,ni
          div = gz(i,j)*( ( (dum1(i+1,j,k)-dum1(i,j,k))*rdx*uh(i)    &
                           +(dum2(i,j+1,k)-dum2(i,j,k))*rdy*vh(j) )  &
                           +(dum3(i,j,k+1)-dum3(i,j,k))*rdsf(k) )
          if(abs(div).lt.smeps) div=0.0
          u2 = temx*dum4(i+1,j,k)*uh(i)
          u1 = temx*dum4(i  ,j,k)*uh(i)
          v2 = temy*dum5(i,j+1,k)*vh(j)
          v1 = temy*dum5(i,j  ,k)*vh(j)
          w2 = dum6(i,j,k+1)
          w1 = dum6(i,j,k  )
          !-----
          ppd(i,j,k)=pp3d(i,j,k)
          pp3d(i,j,k)=pp3d(i,j,k)+dts*( ppten(i,j,k)-ppterm(i,j,k)*div )  &
                 +( -( u2*(piadv(i+1,j,k)-piadv(i  ,j,k))                 &
                      +u1*(piadv(i  ,j,k)-piadv(i-1,j,k)) )               &
                    -( v2*(piadv(i,j+1,k)-piadv(i,j  ,k))                 &
                      +v1*(piadv(i,j  ,k)-piadv(i,j-1,k)) ) )*rr0(i,j,k)*gz(i,j) &
                    +( w1*pk1(i,j,k)+w2*pk2(i,j,k) )
          if(abs(pp3d(i,j,k)).lt.smeps) pp3d(i,j,k)=0.0
          dum1(i,j,k)=kdiv*( pp3d(i,j,k)-ppd(i,j,k) )
          ppd(i,j,k)=pp3d(i,j,k)+dum1(i,j,k)
          !-----
        enddo
        enddo
        enddo

      ENDIF

    ELSE
        ! axisymmetric grid:

        !$omp parallel do default(shared)   &
        !$omp private(i,j,k,div,u1,u2,v1,v2,w1,w2,tem)
        do k=1,nk
        do j=1,nj
        do i=1,ni
          div=(arh2(i)*u3d(i+1,j,k)-arh1(i)*u3d(i,j,k))*rdx*uh(i)   &
             +(w3d(i,j,k+1)-w3d(i,j,k))*rdz*mh(1,1,k)
          if(abs(div).lt.smeps) div=0.0
          u2 = temx*u3d(i+1,j,k)*uh(i)*arh2(i)
          u1 = temx*u3d(i  ,j,k)*uh(i)*arh1(i)
          w2 = w3d(i,j,k+1)
          w1 = w3d(i,j,k  )
          !-----
          ppd(i,j,k)=pp3d(i,j,k)
          pp3d(i,j,k)=pp3d(i,j,k)+dts*( ppten(i,j,k)-ppterm(i,j,k)*div )  &
                    -( u2*(piadv(i+1,j,k)-piadv(i  ,j,k))                 &
                      +u1*(piadv(i  ,j,k)-piadv(i-1,j,k)) )               &
                    +( w1*pk1(i,j,k)+w2*pk2(i,j,k) )
          if(abs(pp3d(i,j,k)).lt.smeps) pp3d(i,j,k)=0.0
          dum1(i,j,k)=kdiv*( pp3d(i,j,k)-ppd(i,j,k) )
          ppd(i,j,k)=pp3d(i,j,k)+dum1(i,j,k)
          !-----
        enddo
        enddo
        enddo

    ENDIF

        IF( n.lt.nloop )THEN
          if(timestats.ge.1) time_sound=time_sound+mytime()
          call bcs(ppd)
          call comm_1s_start(ppd,pw1,pw2,pe1,pe2,   &
                                 ps1,ps2,pn1,pn2,reqs_p)
        ENDIF

!--------------------------------------------------------------------
!  time-averaged velocities:

      IF( get_time_avg )THEN

      if( n.lt.nloop )then
!$omp parallel do default(shared)   &
!$omp private(i,j,k)
        DO k=1,nk
          do j=1,nj
          do i=1,ni+1
            rru(i,j,k)=rru(i,j,k)+u3d(i,j,k)
          enddo
          enddo
          IF( axisymm.eq.0 )THEN
            do j=1,nj+1
            do i=1,ni
              rrv(i,j,k)=rrv(i,j,k)+v3d(i,j,k)
            enddo
            enddo
          ENDIF
          IF( k.ge.2 )THEN
            do j=1,nj
            do i=1,ni
              rrw(i,j,k)=rrw(i,j,k)+w3d(i,j,k)
            enddo
            enddo
          ENDIF
        ENDDO
      else
        tavg = 1.0/float(nloop)
!$omp parallel do default(shared)   &
!$omp private(i,j,k)
        DO k=1,nk
          do j=1,nj
          do i=1,ni+1
            rru(i,j,k)=(rru(i,j,k)+u3d(i,j,k))*tavg
          enddo
          enddo
          IF( axisymm.eq.0 )THEN
            do j=1,nj+1
            do i=1,ni
              rrv(i,j,k)=(rrv(i,j,k)+v3d(i,j,k))*tavg
            enddo
            enddo
          ENDIF
          IF( k.ge.2 )THEN
            do j=1,nj
            do i=1,ni
              rrw(i,j,k)=(rrw(i,j,k)+w3d(i,j,k))*tavg
            enddo
            enddo
          ENDIF
        ENDDO
      endif

      ENDIF
      if(timestats.ge.1) time_sound=time_sound+mytime()

!--------------------------------------------------------------------

      ENDDO  small_step_loop

!  end of small steps
!--------------------------------------------------------------------

      IF( nrk.eq.nrkmax )THEN
        ! pressure tendency term: save for next timestep:
!$omp parallel do default(shared)   &
!$omp private(i,j,k)
        do k=1,nk
        do j=1,nj
        do i=1,ni
          ppx(i,j,k)=dum1(i,j,k)
        enddo
        enddo
        enddo
      ENDIF
      if(timestats.ge.1) time_sound=time_sound+mytime()


      end subroutine sounde

  END MODULE sounde_module
